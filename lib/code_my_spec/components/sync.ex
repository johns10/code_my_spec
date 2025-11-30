defmodule CodeMySpec.Components.Sync do
  @moduledoc """
  Synchronizes context components and their child components from filesystem to database.
  """

  alias CodeMySpec.Components
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Utils.Paths

  @doc """
  Synchronizes a single context component from a spec file path.
  """
  @spec sync_context(Scope.t(), spec_path :: String.t()) ::
          {:ok, Component.t()} | {:error, term()}
  def sync_context(%Scope{} = scope, spec_path) do
    # Parse the spec file
    context_data = parse_context_spec(spec_path)

    if context_data do
      # Upsert the context
      context = upsert_context(scope, context_data)

      # Sync its components
      sync_components(scope, context)

      {:ok, context}
    else
      {:error, :invalid_spec}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Synchronizes all context components from both spec files and implementation files in the project.

  Options:
  - `:base_dir` - Base directory to search for files (defaults to current working directory)
  """
  @spec sync_contexts(Scope.t(), keyword()) :: {:ok, [Component.t()]} | {:error, term()}
  def sync_contexts(%Scope{} = scope, opts \\ []) do
    base_dir = Keyword.get(opts, :base_dir, ".")
    project_module_name = scope.active_project.module_name

    # Scan for spec files
    spec_contexts = find_spec_contexts(project_module_name, base_dir)

    # Scan for implementation files
    impl_contexts = find_impl_contexts(project_module_name, base_dir)

    # Merge the lists
    merged_contexts = merge_context_lists(spec_contexts, impl_contexts)

    # Upsert each context
    synced_contexts =
      Enum.map(merged_contexts, fn context_data ->
        upsert_context(scope, context_data)
      end)

    # Sync components for each context
    Enum.each(synced_contexts, fn context ->
      sync_components(scope, context, opts)
    end)

    # Remove contexts that no longer exist
    cleanup_removed_contexts(scope, synced_contexts)

    {:ok, synced_contexts}
  rescue
    error -> {:error, error}
  end

  @doc """
  Synchronizes all child components belonging to a parent context component from both spec files and implementation files.

  Options:
  - `:base_dir` - Base directory to search for files (defaults to current working directory)
  """
  @spec sync_components(Scope.t(), parent_component :: Component.t(), keyword()) ::
          {:ok, [Component.t()]} | {:error, term()}
  def sync_components(%Scope{} = scope, %Component{} = parent_component, opts \\ []) do
    # Validate parent is a context type
    unless parent_component.type in [:context, :coordination_context] do
      {:error, :parent_not_context}
    else
      do_sync_components(scope, parent_component, opts)
    end
  end

  defp do_sync_components(%Scope{} = scope, %Component{} = parent_component, opts) do
    base_dir = Keyword.get(opts, :base_dir, ".")

    # Find component specs
    spec_components = find_spec_components(parent_component, base_dir)

    # Find implementation files
    impl_components = find_impl_components(parent_component, base_dir)

    # Merge the lists
    merged_components = merge_component_lists(spec_components, impl_components)

    # Upsert each component
    synced_components =
      Enum.map(merged_components, fn component_data ->
        upsert_component(scope, parent_component, component_data)
      end)

    # Remove components that no longer exist
    cleanup_removed_components(scope, parent_component, synced_components)

    {:ok, synced_components}
  rescue
    error -> {:error, error}
  end

  # Private functions

  defp find_spec_contexts(project_module_name, base_dir) do
    spec_dir = Path.join(base_dir, "docs/spec/#{Paths.module_to_path(project_module_name)}")

    if File.dir?(spec_dir) do
      spec_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".spec.md"))
      |> Enum.map(fn filename ->
        path = Path.join(spec_dir, filename)
        parse_context_spec(path)
      end)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  defp find_impl_contexts(project_module_name, base_dir) do
    lib_dir = Path.join(base_dir, "lib/#{Paths.module_to_path(project_module_name)}")

    if File.dir?(lib_dir) do
      lib_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".ex"))
      |> Enum.reject(&should_skip_file?/1)
      |> Enum.map(fn filename ->
        path = Path.join(lib_dir, filename)
        parse_impl_file(path)
      end)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  # Skip common infrastructure files that aren't contexts
  defp should_skip_file?(filename) do
    base_name = Path.basename(filename, ".ex")
    String.downcase(base_name) in ["mailer", "repo", "application"]
  end

  defp find_spec_components(%Component{module_name: module_name}, base_dir) do
    spec_dir = Path.join(base_dir, "docs/spec/#{Paths.module_to_path(module_name)}")

    if File.dir?(spec_dir) do
      Path.wildcard("#{spec_dir}/**/*.spec.md")
      |> Enum.reject(&(Path.basename(&1) == "#{Path.basename(spec_dir)}.spec.md"))
      |> Enum.map(&parse_component_spec/1)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  defp find_impl_components(%Component{module_name: module_name}, base_dir) do
    # Convert module name to lib path
    impl_path = Path.join(base_dir, "lib/#{Paths.module_to_path(module_name)}")

    if File.dir?(impl_path) do
      Path.wildcard("#{impl_path}/**/*.ex")
      |> Enum.reject(&(Path.basename(&1, ".ex") == Path.basename(impl_path)))
      |> Enum.map(&parse_impl_file/1)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  defp parse_context_spec(path) do
    content = File.read!(path)

    # Extract module name from title (first H1)
    module_name =
      case Regex.run(~r/^# (.+)$/m, content) do
        [_, name] -> String.trim(name)
        _ -> nil
      end

    # Extract type from Type field
    type =
      case Regex.run(~r/\*\*Type\*\*:\s*(\w+)/m, content) do
        [_, "context"] -> :context
        [_, "coordination_context"] -> :coordination_context
        _ -> :context
      end

    # Extract description (text after type, before next section)
    description =
      content
      |> String.split("\n")
      |> Enum.drop_while(&(!String.match?(&1, ~r/\*\*Type\*\*/)))
      |> Enum.drop(1)
      |> Enum.take_while(&(!String.match?(&1, ~r/^##/)))
      |> Enum.join("\n")
      |> String.trim()

    if module_name do
      %{
        module_name: module_name,
        type: type,
        description: description,
        spec_path: path,
        impl_path: nil
      }
    else
      nil
    end
  end

  defp parse_component_spec(path) do
    content = File.read!(path)

    # Extract module name from title (first H1)
    module_name =
      case Regex.run(~r/^# (.+)$/m, content) do
        [_, name] -> String.trim(name)
        _ -> nil
      end

    # Extract type from Type field
    type =
      case Regex.run(~r/\*\*Type\*\*:\s*(\w+)/m, content) do
        [_, type_str] -> String.to_existing_atom(type_str)
        _ -> nil
      end

    # Extract description
    description =
      content
      |> String.split("\n")
      |> Enum.drop_while(&(!String.match?(&1, ~r/\*\*Type\*\*/)))
      |> Enum.drop(1)
      |> Enum.take_while(&(!String.match?(&1, ~r/^##/)))
      |> Enum.join("\n")
      |> String.trim()

    if module_name do
      %{
        module_name: module_name,
        type: type,
        description: description,
        spec_path: path,
        impl_path: nil
      }
    else
      nil
    end
  end

  defp parse_impl_file(path) do
    content = File.read!(path)

    # Extract module name using regex
    module_name =
      case Regex.run(~r/defmodule\s+([A-Z][a-zA-Z0-9_.]*)\s+do/m, content) do
        [_, name] -> name
        _ -> nil
      end

    if module_name do
      %{
        module_name: module_name,
        type: nil,
        description: nil,
        spec_path: nil,
        impl_path: path
      }
    else
      nil
    end
  end

  defp merge_context_lists(spec_contexts, impl_contexts) do
    # Create a map keyed by module_name
    spec_map = Map.new(spec_contexts, fn ctx -> {ctx.module_name, ctx} end)
    impl_map = Map.new(impl_contexts, fn ctx -> {ctx.module_name, ctx} end)

    # Get all unique module names
    all_module_names =
      MapSet.union(MapSet.new(Map.keys(spec_map)), MapSet.new(Map.keys(impl_map)))

    # Merge data for each module
    Enum.map(all_module_names, fn module_name ->
      spec_data = Map.get(spec_map, module_name)
      impl_data = Map.get(impl_map, module_name)

      case {spec_data, impl_data} do
        {nil, impl} -> impl
        {spec, nil} -> spec
        {spec, impl} -> Map.merge(spec, %{impl_path: impl.impl_path})
      end
    end)
  end

  defp merge_component_lists(spec_components, impl_components) do
    # Create a map keyed by module_name
    spec_map = Map.new(spec_components, fn comp -> {comp.module_name, comp} end)
    impl_map = Map.new(impl_components, fn comp -> {comp.module_name, comp} end)

    # Get all unique module names
    all_module_names =
      MapSet.union(MapSet.new(Map.keys(spec_map)), MapSet.new(Map.keys(impl_map)))

    # Merge data for each module
    Enum.map(all_module_names, fn module_name ->
      spec_data = Map.get(spec_map, module_name)
      impl_data = Map.get(impl_map, module_name)

      case {spec_data, impl_data} do
        {nil, impl} -> impl
        {spec, nil} -> spec
        {spec, impl} -> Map.merge(spec, %{impl_path: impl.impl_path})
      end
    end)
  end

  defp upsert_context(%Scope{} = scope, context_data) do
    attrs = %{
      module_name: context_data.module_name,
      name: context_data.module_name |> String.split(".") |> List.last(),
      type: context_data.type,
      description: context_data.description,
      parent_component_id: nil
    }

    Components.upsert_component(scope, attrs)
  end

  defp upsert_component(%Scope{} = scope, parent_component, component_data) do
    attrs = %{
      module_name: component_data.module_name,
      name: component_data.module_name |> String.split(".") |> List.last(),
      type: component_data.type,
      description: component_data.description,
      parent_component_id: parent_component.id
    }

    Components.upsert_component(scope, attrs)
  end

  defp cleanup_removed_contexts(%Scope{} = scope, synced_contexts) do
    synced_ids = Enum.map(synced_contexts, & &1.id)

    scope
    |> Components.list_contexts()
    |> Enum.reject(&(&1.id in synced_ids))
    |> Enum.each(&Components.delete_component(scope, &1))
  end

  defp cleanup_removed_components(%Scope{} = scope, parent_component, synced_components) do
    synced_ids = Enum.map(synced_components, & &1.id)

    scope
    |> Components.list_child_components(parent_component.id)
    |> Enum.reject(&(&1.id in synced_ids))
    |> Enum.each(&Components.delete_component(scope, &1))
  end
end
