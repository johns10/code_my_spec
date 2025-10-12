defmodule CodeMySpec.ContentSync.Sync do
  @moduledoc """
  Orchestrates the core content synchronization pipeline from filesystem to database.

  Accepts a directory path, discovers content files in that directory (non-recursive),
  processes them through appropriate parsers and processors, and performs atomic
  database updates. Implements a 'delete all and recreate' strategy where filesystem
  is the source of truth.

  ## Public API

      @spec sync_directory(Scope.t(), directory :: String.t()) :: {:ok, sync_result()} | {:error, term()}

  ## Example

      iex> Sync.sync_directory(scope, "/path/to/content")
      {:ok, %{
        total_files: 10,
        successful: 9,
        errors: 1,
        duration_ms: 1234,
        content_types: %{blog: 5, page: 3, landing: 1}
      }}
  """

  alias CodeMySpec.Content

  alias CodeMySpec.ContentSync.{
    MetaDataParser,
    MarkdownProcessor,
    HtmlProcessor,
    HeexProcessor,
    ProcessorResult
  }

  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope

  @type sync_result :: %{
          total_files: integer(),
          successful: integer(),
          errors: integer(),
          duration_ms: integer(),
          content_types: %{blog: integer(), page: integer(), landing: integer()}
        }

  @doc """
  Syncs a directory of content files to the database.

  ## Parameters

    - `scope` - The user scope containing account and project information
    - `directory` - Absolute path to the directory containing content files

  ## Returns

    - `{:ok, sync_result}` - Successful sync with statistics
    - `{:error, :invalid_directory}` - Directory doesn't exist or isn't readable
    - `{:error, reason}` - Database transaction failure

  ## Processing Steps

  1. Validates directory exists and is readable
  2. Starts database transaction
  3. Deletes all existing content for the project
  4. Discovers content files (*.md, *.html, *.heex) in flat directory structure
  5. Processes each file: reads content, parses metadata, routes to processor
  6. Inserts all content records via batch operation
  7. Commits transaction
  8. Returns sync statistics

  ## Examples

      iex> sync_directory(scope, "/path/to/content")
      {:ok, %{total_files: 3, successful: 3, errors: 0, ...}}

      iex> sync_directory(scope, "/nonexistent")
      {:error, :invalid_directory}
  """
  @spec sync_directory(Scope.t(), String.t()) :: {:ok, sync_result()} | {:error, term()}
  def sync_directory(%Scope{} = scope, directory) do
    start_time = System.monotonic_time(:millisecond)

    with :ok <- validate_directory(directory),
         :ok <- validate_scope(scope) do
      result =
        Repo.transaction(fn ->
          {:ok, _count} = Content.delete_all_content(scope)

          file_paths = discover_files(directory)
          content_attrs_list = Enum.map(file_paths, &process_file(&1, scope))

          case content_attrs_list do
            [] ->
              []

            attrs_list ->
              case Content.create_many(scope, attrs_list) do
                {:ok, content_list} ->
                  content_list

                {:error, reason} ->
                  IO.puts("error?")
                  Repo.rollback(reason)
              end
          end
        end)

      case result do
        {:ok, content_list} ->
          require Logger

          # Log any content items that had parse errors
          content_list
          |> Enum.filter(&(&1.parse_status == :error))
          |> Enum.each(fn content ->
            Logger.error(
              "Content sync error for file #{content.slug} #{inspect(content.parse_errors)}",
              slug: content.slug,
              parse_errors: content.parse_errors,
              raw_content_preview: String.slice(content.raw_content || "", 0, 100)
            )
          end)

          end_time = System.monotonic_time(:millisecond)
          duration_ms = end_time - start_time
          sync_result = build_sync_result(content_list, duration_ms)
          broadcast_sync_completed(scope, sync_result)
          {:ok, sync_result}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # ============================================================================
  # Directory Validation
  # ============================================================================

  @spec validate_directory(String.t() | nil) :: :ok | {:error, :invalid_directory}
  defp validate_directory(nil), do: {:error, :invalid_directory}
  defp validate_directory(""), do: {:error, :invalid_directory}

  defp validate_directory(directory) when is_binary(directory) do
    cond do
      not File.exists?(directory) ->
        {:error, :invalid_directory}

      not File.dir?(directory) ->
        {:error, :invalid_directory}

      true ->
        case File.stat(directory) do
          {:ok, %File.Stat{access: access}} when access in [:read, :read_write] ->
            :ok

          {:ok, _stat} ->
            {:error, :invalid_directory}

          {:error, _reason} ->
            {:error, :invalid_directory}
        end
    end
  end

  # ============================================================================
  # Scope Validation
  # ============================================================================

  @spec validate_scope(Scope.t()) :: :ok | {:error, term()}
  defp validate_scope(%Scope{active_project_id: nil}), do: {:error, :no_active_project}
  defp validate_scope(%Scope{active_account_id: nil}), do: {:error, :no_active_account}
  defp validate_scope(%Scope{}), do: :ok

  # ============================================================================
  # File Discovery
  # ============================================================================

  @spec discover_files(String.t()) :: [String.t()]
  defp discover_files(directory) do
    patterns = [
      Path.join(directory, "*.md"),
      Path.join(directory, "*.html"),
      Path.join(directory, "*.heex")
    ]

    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
    |> Enum.filter(&has_metadata_file?/1)
    |> Enum.sort()
  end

  @spec has_metadata_file?(String.t()) :: boolean()
  defp has_metadata_file?(file_path) do
    metadata_path = Path.rootname(file_path) <> ".yaml"
    File.exists?(metadata_path)
  end

  # ============================================================================
  # File Processing
  # ============================================================================

  @spec process_file(String.t(), Scope.t()) :: map()
  defp process_file(file_path, _scope) do
    raw_content = File.read!(file_path)
    extension = Path.extname(file_path)
    metadata_path = Path.rootname(file_path) <> ".yaml"

    case MetaDataParser.parse_metadata_file(metadata_path) do
      {:ok, metadata} ->
        processor_result = route_to_processor(extension, raw_content)
        merge_metadata_and_result(metadata, processor_result)

      {:error, error_detail} ->
        build_metadata_error_attrs(raw_content, error_detail)
    end
  end

  @spec route_to_processor(String.t(), String.t()) :: ProcessorResult.t()
  defp route_to_processor(".md", raw_content) do
    {:ok, result} = MarkdownProcessor.process(raw_content)
    result
  end

  defp route_to_processor(".html", raw_content) do
    {:ok, result} = HtmlProcessor.process(raw_content)
    result
  end

  defp route_to_processor(".heex", raw_content) do
    {:ok, result} = HeexProcessor.process(raw_content)
    result
  end

  @spec merge_metadata_and_result(map(), ProcessorResult.t()) :: map()
  defp merge_metadata_and_result(metadata, %ProcessorResult{} = result) do
    base_attrs = %{
      slug: metadata[:slug],
      title: metadata[:title],
      content_type: atomize_content_type(metadata[:type]),
      raw_content: result.raw_content,
      processed_content: result.processed_content,
      parse_status: result.parse_status,
      parse_errors: atomize_parse_errors(result.parse_errors),
      metadata: %{}
    }

    optional_attrs = %{
      publish_at: parse_datetime(metadata[:publish_at]),
      expires_at: parse_datetime(metadata[:expires_at]),
      meta_title: metadata[:meta_title],
      meta_description: metadata[:meta_description],
      og_image: metadata[:og_image],
      og_title: metadata[:og_title],
      og_description: metadata[:og_description],
      protected: metadata[:protected]
    }

    base_attrs
    |> Map.merge(optional_attrs)
    |> reject_nil_values()
  end

  @spec build_metadata_error_attrs(String.t(), map()) :: map()
  defp build_metadata_error_attrs(raw_content, error_detail) do
    %{
      slug: generate_error_slug(),
      content_type: :blog,
      raw_content: raw_content,
      processed_content: nil,
      parse_status: :error,
      parse_errors: %{
        error_type: "MetaDataParseError",
        message:
          Map.get(error_detail, :message) || Map.get(error_detail, "message") || "Unknown error",
        details: serialize_error_detail(error_detail)
      },
      metadata: %{}
    }
  end

  @spec serialize_error_detail(map()) :: map()
  defp serialize_error_detail(error_detail) when is_map(error_detail) do
    # Convert any nested structs to maps
    Enum.reduce(error_detail, %{}, fn {key, value}, acc ->
      Map.put(acc, key, serialize_value(value))
    end)
  end

  defp serialize_value(%YamlElixir.ParsingError{} = error) do
    %{
      line: error.line,
      column: error.column,
      type: error.type,
      message: error.message
    }
  end

  defp serialize_value(value) when is_struct(value) do
    Map.from_struct(value)
  end

  defp serialize_value(value), do: value

  @spec atomize_parse_errors(map() | nil) :: map() | nil
  defp atomize_parse_errors(nil), do: nil
  defp atomize_parse_errors(errors) when is_map(errors), do: errors

  @spec generate_error_slug() :: String.t()
  defp generate_error_slug do
    "error-" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  @spec atomize_content_type(String.t() | nil) :: atom()
  defp atomize_content_type("blog"), do: :blog
  defp atomize_content_type("page"), do: :page
  defp atomize_content_type("landing"), do: :landing
  defp atomize_content_type(_), do: :blog

  @spec parse_datetime(String.t() | DateTime.t() | nil) :: DateTime.t() | nil
  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> nil
    end
  end

  defp parse_datetime(_), do: nil

  @spec reject_nil_values(map()) :: map()
  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # ============================================================================
  # Sync Result Calculation
  # ============================================================================

  @spec build_sync_result([Content.Content.t()], integer()) :: sync_result()
  defp build_sync_result(content_list, duration_ms) do
    successful = Enum.count(content_list, &(&1.parse_status == :success))
    errors = Enum.count(content_list, &(&1.parse_status == :error))

    content_types = %{
      blog: count_content_type(content_list, :blog, :success),
      page: count_content_type(content_list, :page, :success),
      landing: count_content_type(content_list, :landing, :success)
    }

    %{
      total_files: length(content_list),
      successful: successful,
      errors: errors,
      duration_ms: duration_ms,
      content_types: content_types
    }
  end

  @spec count_content_type([Content.Content.t()], atom(), atom()) :: integer()
  defp count_content_type(content_list, type, status) do
    Enum.count(content_list, fn content ->
      content.content_type == type and content.parse_status == status
    end)
  end

  # ============================================================================
  # Broadcasting
  # ============================================================================

  @spec broadcast_sync_completed(Scope.t(), sync_result()) :: :ok | {:error, term()}
  defp broadcast_sync_completed(%Scope{} = scope, sync_result) do
    Phoenix.PubSub.broadcast(
      CodeMySpec.PubSub,
      content_topic(scope),
      {:sync_completed, sync_result}
    )
  end

  @spec content_topic(Scope.t()) :: String.t()
  defp content_topic(%Scope{} = scope) do
    "account:#{scope.active_account_id}:project:#{scope.active_project_id}:content"
  end
end
