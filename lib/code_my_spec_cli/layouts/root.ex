defmodule CodeMySpecCli.Layouts.Root do
  @moduledoc """
  Root layout for the CLI application.
  Handles the overall structure and styling.
  """

  @doc """
  Wraps content in the root layout.
  """
  def render(content) do
    [
      header(),
      "\n",
      job_status(),
      content,
      "\n",
      footer()
    ]
  end

  defp header do
    Owl.Data.tag(String.duplicate("═", 80), :cyan)
  end

  defp job_status do
    # Render the job status component
    status = CodeMySpecCli.Components.JobStatus.render()

    if status != "" do
      [status, "\n"]
    else
      ""
    end
  end

  defp footer do
    Owl.Data.tag(String.duplicate("═", 80), :cyan)
  end

  @doc """
  Clears the screen
  """
  def clear_screen do
    # Use ANSI escape codes to clear screen
    IO.write("\e[2J\e[H")
  end
end