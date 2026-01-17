defmodule CodeMySpec.Components.Sync do
  @moduledoc """
  Synchronizes components from filesystem to database. Parent-child relationships
  are derived from module name hierarchy.
  """

  require Logger

  alias CodeMySpec.Components
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Components.Sync.FileInfo
  alias CodeMySpec.Users.Scope

  @doc """
  Synchronizes all components from spec files and implementation files.

  Module names come from:
  1. Implementation's declared module name (highest priority)
  2. Spec's H1 title
  3. Path-derived name (lowest priority)

  Component type is determined by namespace depth:
  - 2 parts (e.g., MyApp.Accounts) → context_spec
  - 3+ parts (e.g., MyApp.Accounts.User) → spec

  ## Options

  - `:base_dir` - Base directory to scan (defaults to current working directory)
  - `:force` - When true, ignores mtime and syncs all files (defaults to false)
  """
  @type parse_error :: {path :: String.t(), reason :: term()}

  @spec sync_all(Scope.t(), keyword()) ::
          {:ok, [Component.t()], [parse_error()]} | {:error, term()}
  def sync_all(%Scope{} = scope, opts \\ []) do
    base_dir = Keyword.get(opts, :base_dir, ".")
    force = Keyword.get(opts, :force, false)

    existing_components = Components.list_components(scope)
    synced_at_map = Map.new(existing_components, fn c -> {c.module_name, c.synced_at} end)

    # Parse spec and impl files
    spec_file_infos = FileInfo.collect_files(base_dir, "docs/spec/**/*.spec.md")
    impl_file_infos = FileInfo.collect_files(base_dir, "lib/**/*.ex")

    {spec_data, spec_errors} = parse_files(spec_file_infos, &parse_spec_file(&1, base_dir))
    {impl_data, impl_errors} = parse_files(impl_file_infos, &parse_impl_file(&1, base_dir))

    parse_errors = spec_errors ++ impl_errors

    Enum.each(parse_errors, fn {path, error} ->
      Logger.warning("Failed to parse #{path}: #{inspect(error)}")
    end)

    # Merge by module name (impl takes precedence)
    merged = merge_by_module_name(spec_data, impl_data)

    # Filter to components needing sync
    {to_sync, unchanged} =
      Enum.split_with(merged, &needs_sync?(&1, synced_at_map, force))

    # Upsert changed components
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    synced = Enum.map(to_sync, &upsert_from_data(scope, &1, now))

    # Get unchanged from DB
    unchanged_names = MapSet.new(unchanged, & &1.module_name)
    unchanged_components = Enum.filter(existing_components, &(&1.module_name in unchanged_names))

    all_components = synced ++ unchanged_components

    # Derive parent relationships and cleanup
    derive_parent_relationships(scope, all_components)
    cleanup_removed(scope, existing_components, MapSet.new(merged, & &1.module_name))

    {:ok, all_components, parse_errors}
  rescue
    error ->
      Logger.error("Error during sync: #{inspect(error)}")
      {:error, error}
  end

  # --- Parsing ---

  defp parse_files(file_infos, parse_fn) do
    {successes, failures} =
      file_infos
      |> Enum.map(fn file_info ->
        try do
          {:ok, parse_fn.(file_info)}
        rescue
          error -> {:error, file_info.path, error}
        end
      end)
      |> Enum.split_with(&match?({:ok, _}, &1))

    data = Enum.map(successes, fn {:ok, d} -> d end)
    errors = Enum.map(failures, fn {:error, path, err} -> {path, err} end)
    {data, errors}
  end

  defp parse_spec_file(%FileInfo{path: path, mtime: mtime}, base_dir) do
    content = File.read!(path)

    # Get module name from H1 title
    module_name = extract_h1_title(content) || derive_module_from_path(path, base_dir, :spec)

    # Extract description from intro text (content after H1, before first H2)
    description = extract_intro_text(content)

    %{
      module_name: module_name,
      type: type_from_namespace(module_name),
      description: description,
      spec_path: path,
      impl_path: nil,
      mtime: mtime
    }
  end

  defp parse_impl_file(%FileInfo{path: path, mtime: mtime}, base_dir) do
    content = File.read!(path)

    module_name =
      case Regex.run(~r/defmodule\s+([A-Z][a-zA-Z0-9_.]*)\s+do/m, content) do
        [_, name] -> name
        _ -> derive_module_from_path(path, base_dir, :impl)
      end

    %{
      module_name: module_name,
      type: type_from_namespace(module_name),
      description: nil,
      spec_path: nil,
      impl_path: path,
      mtime: mtime
    }
  end

  defp extract_h1_title(content) do
    case Regex.run(~r/^# ([A-Z][a-zA-Z0-9_.]+)$/m, content) do
      [_, name] -> String.trim(name)
      _ -> nil
    end
  end

  defp extract_intro_text(content) do
    content
    |> String.split("\n")
    |> Enum.drop_while(&(!String.match?(&1, ~r/^# [A-Z]/)))
    |> Enum.drop(1)
    |> Enum.take_while(&(!String.match?(&1, ~r/^##/)))
    |> Enum.join("\n")
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp derive_module_from_path(path, base_dir, :spec) do
    path
    |> String.replace_prefix("#{base_dir}/", "")
    |> String.replace_prefix("docs/spec/", "")
    |> String.replace_suffix(".spec.md", "")
    |> path_to_module()
  end

  defp derive_module_from_path(path, base_dir, :impl) do
    path
    |> String.replace_prefix("#{base_dir}/", "")
    |> String.replace_prefix("lib/", "")
    |> String.replace_suffix(".ex", "")
    |> path_to_module()
  end

  defp path_to_module(path) do
    path
    |> String.split("/")
    |> Enum.map(&camelize/1)
    |> Enum.join(".")
  end

  defp camelize(string) do
    string
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
  end

  @doc """
  Determines component type from module namespace depth.

  - 2 parts (e.g., MyApp.Accounts) → "context"
  - 3+ parts (e.g., MyApp.Accounts.User) → "module"
  """
  def type_from_namespace(module_name) when is_binary(module_name) do
    parts = String.split(module_name, ".")

    case length(parts) do
      n when n <= 2 -> "context"
      _ -> "module"
    end
  end

  # --- Merging ---

  defp merge_by_module_name(spec_data, impl_data) do
    spec_map = Map.new(spec_data, &{&1.module_name, &1})
    impl_map = Map.new(impl_data, &{&1.module_name, &1})

    all_names = MapSet.union(MapSet.new(Map.keys(spec_map)), MapSet.new(Map.keys(impl_map)))

    Enum.map(all_names, fn name ->
      spec = Map.get(spec_map, name)
      impl = Map.get(impl_map, name)

      case {spec, impl} do
        {nil, impl} -> impl
        {spec, nil} -> spec
        {spec, impl} -> merge_spec_impl(spec, impl)
      end
    end)
  end

  defp merge_spec_impl(spec, impl) do
    %{
      module_name: impl.module_name,
      type: spec.type || impl.type,
      description: spec.description,
      spec_path: spec.spec_path,
      impl_path: impl.impl_path,
      mtime: latest_mtime(spec.mtime, impl.mtime)
    }
  end

  defp latest_mtime(nil, mtime), do: mtime
  defp latest_mtime(mtime, nil), do: mtime
  defp latest_mtime(m1, m2), do: if(DateTime.compare(m1, m2) == :gt, do: m1, else: m2)

  # --- Sync logic ---

  defp needs_sync?(_data, _map, true), do: true

  defp needs_sync?(data, synced_at_map, false) do
    case Map.get(synced_at_map, data.module_name) do
      nil -> true
      synced_at -> DateTime.compare(data.mtime, synced_at) == :gt
    end
  end

  defp upsert_from_data(%Scope{} = scope, data, synced_at) do
    attrs = %{
      module_name: data.module_name,
      name: data.module_name |> String.split(".") |> List.last(),
      type: data.type || "module",
      description: data.description,
      parent_component_id: nil,
      synced_at: synced_at
    }

    Components.upsert_component(scope, attrs)
  end

  defp derive_parent_relationships(scope, components) do
    component_map = Map.new(components, &{&1.module_name, &1})

    Enum.each(components, fn component ->
      case find_nearest_ancestor(component.module_name, component_map) do
        nil ->
          :ok

        parent when parent.id != component.id ->
          Components.update_component(scope, component, %{parent_component_id: parent.id})

        _ ->
          :ok
      end
    end)
  end

  # Walks up the module namespace tree to find the nearest existing ancestor.
  # For example, if "A.B.C.D" has no "A.B.C" component, it will check "A.B", then "A".
  defp find_nearest_ancestor(module_name, component_map) do
    case parent_module_name(module_name) do
      nil ->
        nil

      parent_name ->
        case Map.get(component_map, parent_name) do
          nil -> find_nearest_ancestor(parent_name, component_map)
          parent -> parent
        end
    end
  end

  defp parent_module_name(module_name) do
    parts = String.split(module_name, ".")

    if length(parts) > 1 do
      parts |> Enum.drop(-1) |> Enum.join(".")
    else
      nil
    end
  end

  defp cleanup_removed(%Scope{} = scope, existing, current_names) do
    existing
    |> Enum.reject(&(&1.module_name in current_names))
    |> Enum.each(&Components.delete_component(scope, &1))
  end
end
