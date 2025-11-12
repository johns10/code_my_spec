defmodule CodeMySpec.ContentSync.MetaDataParser do
  @moduledoc """
  Parses sidecar `.yaml` files to extract structured metadata for content files.

  Returns success tuples with parsed metadata maps or error tuples with details
  when files are missing, contain invalid YAML syntax, or have malformed structure.

  ## Example

      iex> MetaDataParser.parse_metadata_file("content/posts/my-post.yaml")
      {:ok, %{title: "My Post", slug: "my-post", type: "blog"}}

      iex> MetaDataParser.parse_metadata_file("missing.yaml")
      {:error, %{type: :file_not_found, message: "Metadata file not found", ...}}
  """

  @known_fields ~w(
    title slug type publish_at expires_at
    meta_title meta_description og_image og_title og_description
    tags protected
  )

  @required_fields [:title, :slug, :type]

  @type metadata :: %{
          required(:title) => String.t(),
          required(:slug) => String.t(),
          required(:type) => String.t(),
          optional(:publish_at) => DateTime.t() | String.t(),
          optional(:expires_at) => DateTime.t() | String.t(),
          optional(:meta_title) => String.t(),
          optional(:meta_description) => String.t(),
          optional(:og_image) => String.t(),
          optional(:og_title) => String.t(),
          optional(:og_description) => String.t(),
          optional(:tags) => [String.t()],
          optional(:protected) => boolean(),
          optional(String.t()) => any()
        }

  @type error_detail :: %{
          type: :file_not_found | :yaml_parse_error | :invalid_structure,
          message: String.t(),
          file_path: String.t(),
          details: any()
        }

  @doc """
  Parses a YAML metadata file and returns structured metadata.

  ## Parameters

    - `file_path` - Path to the `.yaml` metadata file

  ## Returns

    - `{:ok, metadata}` - Successfully parsed metadata map with atom keys for known fields
    - `{:error, error_detail}` - Error details when parsing fails

  ## Examples

      iex> parse_metadata_file("content/posts/my-post.yaml")
      {:ok, %{title: "My Post", slug: "my-post", type: "blog"}}
  """
  @spec parse_metadata_file(file_path :: String.t()) ::
          {:ok, metadata()} | {:error, error_detail()}
  def parse_metadata_file(file_path) do
    with {:ok, content} <- read_file(file_path),
         {:ok, parsed} <- parse_yaml(content, file_path),
         {:ok, validated} <- validate_structure(parsed, file_path) do
      {:ok, convert_keys(validated)}
    end
  end

  defp read_file(file_path) do
    case File.read(file_path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> file_not_found_error(file_path)
      {:error, reason} -> file_not_found_error(file_path, reason)
    end
  end

  defp parse_yaml(content, file_path) do
    case YamlElixir.read_from_string(content) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, error} -> yaml_parse_error(file_path, error)
    end
  end

  defp validate_structure(parsed, file_path) when is_map(parsed) do
    parsed_with_atom_keys = atomize_known_keys(parsed)

    missing_fields =
      @required_fields
      |> Enum.reject(&Map.has_key?(parsed_with_atom_keys, &1))

    case missing_fields do
      [] -> {:ok, parsed}
      _ -> invalid_structure_error(file_path, parsed)
    end
  end

  defp validate_structure(parsed, file_path) do
    invalid_structure_error(file_path, parsed)
  end

  defp atomize_known_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      atom_key = try_atomize_key(key)
      Map.put(acc, atom_key, value)
    end)
  end

  defp try_atomize_key(key) when is_binary(key) do
    if key in @known_fields do
      String.to_existing_atom(key)
    else
      key
    end
  rescue
    ArgumentError -> key
  end

  defp try_atomize_key(key), do: key

  defp convert_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      new_key =
        if is_binary(key) and key in @known_fields do
          String.to_existing_atom(key)
        else
          key
        end

      Map.put(acc, new_key, value)
    end)
  end

  defp file_not_found_error(file_path, details \\ nil) do
    {:error,
     %{
       type: :file_not_found,
       message: "Metadata file not found",
       file_path: file_path,
       details: details
     }}
  end

  defp yaml_parse_error(file_path, error) do
    {:error,
     %{
       type: :yaml_parse_error,
       message: "Invalid YAML syntax",
       file_path: file_path,
       details: error
     }}
  end

  defp invalid_structure_error(file_path, parsed) do
    {:error,
     %{
       type: :invalid_structure,
       message: "Metadata must be a map with required keys",
       file_path: file_path,
       details: parsed
     }}
  end
end
