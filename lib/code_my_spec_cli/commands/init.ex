defmodule CodeMySpecCli.Commands.Init do
  @moduledoc """
  Initialize CodeMySpec in a Phoenix project
  """

  def run(flags) do
    IO.puts("🚀 Initializing CodeMySpec...")

    unless File.exists?("mix.exs") do
      IO.puts("❌ No mix.exs found. Run from Phoenix project root.")
      System.halt(1)
    end

    File.mkdir_p!(".codemyspec")

    config = %{
      version: "0.1.0",
      contexts: [],
      initialized_at: DateTime.utc_now()
    }

    config_path = ".codemyspec/config.json"

    if File.exists?(config_path) and not flags[:force] do
      IO.puts("⚠️  Config exists. Use --force to overwrite.")
      System.halt(1)
    end

    File.write!(config_path, Jason.encode!(config, pretty: true))

    IO.puts("✅ CodeMySpec initialized!")
    IO.puts("\nNext steps:")
    IO.puts("  codemyspec generate           - Generate code from stories")
    IO.puts("  codemyspec dashboard           - Monitor active sessions")
  end
end
