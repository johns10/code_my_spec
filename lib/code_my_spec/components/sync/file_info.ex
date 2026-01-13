defmodule CodeMySpec.Components.Sync.FileInfo do
  @moduledoc """
  Struct representing a file's metadata for sync comparison.
  """

  defstruct [:path, :mtime]

  @type t :: %__MODULE__{
          path: String.t(),
          mtime: DateTime.t()
        }

  @doc """
  Creates a FileInfo struct from a file path by reading its modification time.

  Raises if the file does not exist.
  """
  @spec from_path(String.t()) :: t()
  def from_path(path) when is_binary(path) do
    %File.Stat{mtime: mtime} = File.stat!(path)

    %__MODULE__{
      path: path,
      mtime: erl_datetime_to_utc(mtime)
    }
  end

  @doc """
  Collects all files matching a glob pattern as FileInfo structs.
  """
  @spec collect_files(base_dir :: String.t(), glob :: String.t()) :: [t()]
  def collect_files(base_dir, glob) when is_binary(base_dir) and is_binary(glob) do
    base_dir
    |> Path.join(glob)
    |> Path.wildcard()
    |> Enum.map(&from_path/1)
  end

  defp erl_datetime_to_utc({{year, month, day}, {hour, minute, second}}) do
    {:ok, naive} = NaiveDateTime.new(year, month, day, hour, minute, second)
    DateTime.from_naive!(naive, "Etc/UTC")
  end
end
