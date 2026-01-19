defmodule CodeMySpec.FileEdits do
  @moduledoc """
  Tracks file edits by external session ID (e.g., Claude Code conversation).
  """

  import Ecto.Query
  alias CodeMySpec.Repo
  alias CodeMySpec.FileEdits.FileEdit

  @doc """
  Record a file edit for an external session.
  Ignores duplicates (same session + file_path).
  """
  @spec track_edit(String.t(), String.t()) :: :ok
  def track_edit(external_session_id, file_path) do
    %FileEdit{}
    |> Ecto.Changeset.change(external_session_id: external_session_id, file_path: file_path)
    |> Repo.insert(on_conflict: :nothing)

    :ok
  end

  @doc """
  Get all file paths edited in an external session.
  """
  @spec get_edited_files(String.t()) :: [String.t()]
  def get_edited_files(external_session_id) do
    FileEdit
    |> where([e], e.external_session_id == ^external_session_id)
    |> select([e], e.file_path)
    |> Repo.all()
  end

  @doc """
  Clear all edits for an external session.
  """
  @spec clear_edits(String.t()) :: :ok
  def clear_edits(external_session_id) do
    FileEdit
    |> where([e], e.external_session_id == ^external_session_id)
    |> Repo.delete_all()

    :ok
  end
end
