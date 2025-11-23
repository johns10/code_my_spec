defmodule CodeMySpecCli.Commands.Generate do
  @moduledoc """
  Generate code from stories
  """

  alias CodeMySpecCli.SessionManager

  def run(args, opts) do
    IO.puts("🏗️  Generating code...")

    if opts[:interactive] do
      CodeMySpecCli.Commands.Dashboard.run()
    else
      story_ids = parse_story_ids(args[:story_ids])

      if Enum.empty?(story_ids) do
        IO.puts("No story IDs provided. Launching dashboard...")
        CodeMySpecCli.Commands.Dashboard.run()
      else
        start_generation(story_ids, opts)
      end
    end
  end

  defp start_generation(story_ids, opts) do
    Enum.each(story_ids, fn story_id ->
      # TODO: Fetch from MCP/web app
      context_name = opts[:context] || "DefaultContext"
      prompt = build_prompt(story_id, context_name)

      case SessionManager.start_session(context_name, story_id, prompt) do
        {:ok, session} ->
          IO.puts("✅ Started session #{session.id} for #{context_name} / Story #{story_id}")

        {:error, reason} ->
          IO.puts("❌ Failed to start session: #{inspect(reason)}")
      end
    end)

    IO.puts("\n📊 Monitor sessions: codemyspec dashboard")
    IO.puts("📝 List sessions: codemyspec session list")
  end

  defp parse_story_ids(nil), do: []

  defp parse_story_ids(ids) when is_binary(ids) do
    ids |> String.split(",") |> Enum.map(&String.trim/1)
  end

  defp build_prompt(story_id, context_name) do
    """
    Generate code for Story #{story_id} in the #{context_name} context.

    Follow these guidelines:
    1. Use the existing CodeMySpec architecture
    2. Follow Phoenix best practices
    3. Write comprehensive tests
    4. Update documentation as needed

    When complete, run tests and ensure they pass.
    """
  end
end
