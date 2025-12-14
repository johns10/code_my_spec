defmodule CodeMySpecCli.Commands.SubmitResult do
  @moduledoc """
  Command to submit a result for the current session interaction.

  This is typically used inside a tmux window where a session command
  was executed. The user runs this after the command completes to
  submit the result and move to the next command.

  Usage:
    /submit_result <interaction_id> <exit_code>
    /submit_result <interaction_id> success
    /submit_result <interaction_id> error

  The output is automatically captured from the tmux pane.
  """

  use CodeMySpecCli.Commands.CommandBehaviour

  alias CodeMySpec.Sessions
  alias CodeMySpecCli.TmuxManager

  @impl true
  def execute(scope, args) do
    case args do
      [interaction_id, status_or_code] ->
        # Parse the status
        {status, exit_code} = parse_status(status_or_code)

        # Try to get the current tmux window to capture output
        output = capture_current_pane_output()

        result_attrs = %{
          status: status,
          output: output,
          exit_code: exit_code
        }

        # Find the session by interaction ID
        case find_session_for_interaction(scope, interaction_id) do
          {:ok, session_id} ->
            case Sessions.handle_result(scope, session_id, interaction_id, result_attrs) do
              {:ok, _session} ->
                {:ok, "Result submitted successfully. Fetching next command..."}

              {:error, reason} ->
                {:error, "Failed to submit result: #{inspect(reason)}"}
            end

          {:error, :not_found} ->
            {:error, "Could not find session for interaction ID: #{interaction_id}"}
        end

      _ ->
        {:error, """
        Usage: /submit_result <interaction_id> <status>

        Examples:
          /submit_result abc123 0          (exit code 0)
          /submit_result abc123 1          (exit code 1)
          /submit_result abc123 success    (status: ok)
          /submit_result abc123 error      (status: error)
        """}
    end
  end

  # Parse status argument
  defp parse_status("success"), do: {:ok, 0}
  defp parse_status("ok"), do: {:ok, 0}
  defp parse_status("error"), do: {:error, 1}
  defp parse_status("failed"), do: {:error, 1}

  defp parse_status(code_str) do
    case Integer.parse(code_str) do
      {code, _} when code == 0 -> {:ok, code}
      {code, _} -> {:error, code}
      :error -> {:error, 1}
    end
  end

  # Capture output from the current tmux pane
  defp capture_current_pane_output do
    if TmuxManager.inside_tmux?() do
      # Get the current window name from TMUX_PANE environment variable
      case System.get_env("TMUX_PANE") do
        nil ->
          ""

        _pane_id ->
          # Capture the pane content
          case System.cmd("tmux", ["capture-pane", "-p"]) do
            {output, 0} -> output
            _ -> ""
          end
      end
    else
      ""
    end
  end

  # Find which session owns this interaction
  defp find_session_for_interaction(scope, interaction_id) do
    # List all active sessions and search for the interaction
    sessions = Sessions.list_sessions(scope, status: [:active])

    session =
      Enum.find(sessions, fn session ->
        Enum.any?(session.interactions, fn interaction ->
          interaction.id == interaction_id
        end)
      end)

    if session do
      {:ok, session.id}
    else
      {:error, :not_found}
    end
  end
end
