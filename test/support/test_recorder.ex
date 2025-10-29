defmodule CodeMySpec.TestRecorder do
  @moduledoc """
  Simple record/replay helper for testing.

  Records function results to disk on first run, then replays them on subsequent runs.
  Works with any Elixir term - HTTP responses, protobuf structs, database results, etc.

  ## Usage

      test "my test" do
        result = TestRecorder.record_or_replay("my_cassette", fn ->
          # This function runs ONCE and gets recorded
          expensive_api_call()
        end)

        assert result == expected
      end

  ## Re-recording

  To force re-recording, either:
  - Delete the cassette file: `rm test/cassettes/my_cassette.etf`
  - Set env var: `RERECORD=true mix test`
  - Use `record_or_replay/3` with `force_record: true`
  """

  @cassette_dir "test/cassettes"

  @doc """
  Records the result of `fun` to a cassette file, or replays from cassette if it exists.

  ## Examples

      iex> TestRecorder.record_or_replay("my_test", fn -> {:ok, "data"} end)
      {:ok, "data"}

  ## Options

  - `:force_record` - Force re-recording even if cassette exists (default: false)
  """
  def record_or_replay(cassette_name, fun, opts \\ []) do
    force_record = Keyword.get(opts, :force_record, false)
    rerecord = System.get_env("RERECORD") in ["1", "true"]
    path = cassette_path(cassette_name)

    if File.exists?(path) and not force_record and not rerecord do
      # Replay from cassette
      replay(path)
    else
      # Record new cassette
      record(path, fun)
    end
  end

  @doc """
  Deletes a cassette file to force re-recording on next test run.
  """
  def delete_cassette(cassette_name) do
    path = cassette_path(cassette_name)
    File.rm(path)
  end

  @doc """
  Deletes all cassette files.
  """
  def delete_all_cassettes do
    if File.exists?(@cassette_dir) do
      File.rm_rf!(@cassette_dir)
    end
  end

  # Private functions

  defp cassette_path(cassette_name) do
    Path.join(@cassette_dir, "#{cassette_name}.etf")
  end

  defp replay(path) do
    path
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  defp record(path, fun) do
    result = fun.()
    File.mkdir_p!(@cassette_dir)
    File.write!(path, :erlang.term_to_binary(result))
    result
  end
end
