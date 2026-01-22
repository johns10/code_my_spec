defmodule CodeMySpecCli.Release.PackageExtension do
  @moduledoc """
  Burrito post-build step that packages the CodeMySpec Claude Code extension.

  This step:
  1. Creates a release directory with extension files
  2. Updates command references from dev mode to production binary
  3. Copies the binary for GitHub Release upload
  4. Creates an install script that downloads the binary
  """

  @behaviour Burrito.Builder.Step

  @binary_name "cms"
  @release_dir "codemyspec-extension"
  @github_repo "Code-My-Spec/code_my_spec_claude_code_extension"

  @impl true
  def execute(%Burrito.Builder.Context{} = context) do
    log("Packaging CodeMySpec extension...")

    app_path = File.cwd!()
    release_name = Atom.to_string(context.mix_release.name)
    target_name = Atom.to_string(context.target.alias)

    # Source paths
    source_binary = Path.join([app_path, "burrito_out", "#{release_name}_#{target_name}"])
    source_extension = Path.join(app_path, "CodeMySpec")

    # Output paths
    release_base = Path.join(app_path, "release")
    extension_dir = Path.join(release_base, @release_dir)
    binaries_dir = Path.join(release_base, "binaries")

    # Clean and create directories
    File.rm_rf!(extension_dir)
    File.rm_rf!(binaries_dir)
    File.mkdir_p!(extension_dir)
    File.mkdir_p!(binaries_dir)

    # Copy extension directories
    copy_extension_files(source_extension, extension_dir)
    log("Copied extension files")

    # Update command references
    update_command_references(extension_dir)
    log("Updated command references")

    # Copy binary for GitHub Release
    binary_name = binary_name_for_target(context.target)
    target_binary = Path.join(binaries_dir, binary_name)
    File.copy!(source_binary, target_binary)
    File.chmod!(target_binary, 0o755)
    log("Copied binary to #{target_binary}")

    # Create install script
    create_install_script(extension_dir)
    log("Created install script")

    # Create README
    create_readme(extension_dir)
    log("Created README")

    # Create .gitignore
    create_gitignore(extension_dir)

    log("Extension packaged to: #{extension_dir}")
    log("Binary ready for upload: #{target_binary}")

    # Get version from plugin.json
    version = get_plugin_version(extension_dir)

    # Push to GitHub and create release (if PUBLISH_RELEASE env var is set)
    if System.get_env("PUBLISH_RELEASE") == "true" do
      log("Publishing release v#{version}...")
      push_to_github(extension_dir, version)
      create_github_release(target_binary, binary_name, version)
      log("Release v#{version} published!")
    else
      log("Skipping publish (set PUBLISH_RELEASE=true to publish)")
    end

    context
  end

  defp get_plugin_version(extension_dir) do
    plugin_json_path = Path.join([extension_dir, ".claude-plugin", "plugin.json"])

    case File.read(plugin_json_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"version" => version}} -> version
          _ -> "0.1.0"
        end

      _ ->
        "0.1.0"
    end
  end

  defp push_to_github(extension_dir, version) do
    # Initialize git repo if needed
    unless File.exists?(Path.join(extension_dir, ".git")) do
      run_cmd("git", ["init"], extension_dir)

      run_cmd(
        "git",
        ["remote", "add", "origin", "https://github.com/#{@github_repo}.git"],
        extension_dir
      )
    end

    # Commit and push
    run_cmd("git", ["add", "."], extension_dir)
    run_cmd("git", ["commit", "-m", "Release v#{version}", "--allow-empty"], extension_dir)
    run_cmd("git", ["tag", "-f", "v#{version}"], extension_dir)
    run_cmd("git", ["push", "-u", "origin", "main", "--force"], extension_dir)
    run_cmd("git", ["push", "origin", "v#{version}", "--force"], extension_dir)
  end

  defp create_github_release(binary_path, _binary_name, version) do
    # Use GitHub CLI (gh) to create release and upload binary
    tag = "v#{version}"

    # Delete existing release if it exists (ignore errors)
    System.cmd("gh", ["release", "delete", tag, "--yes", "--repo", @github_repo],
      stderr_to_stdout: true
    )

    # Create new release and upload binary
    {output, exit_code} =
      System.cmd(
        "gh",
        [
          "release",
          "create",
          tag,
          binary_path,
          "--repo",
          @github_repo,
          "--title",
          "Release #{tag}",
          "--notes",
          "CodeMySpec CLI release #{tag}\n\nDownload the binary for your platform and run `./install.sh` to install."
        ],
        stderr_to_stdout: true
      )

    if exit_code != 0 do
      log("Warning: Failed to create GitHub release: #{output}")
    else
      log("GitHub release created: https://github.com/#{@github_repo}/releases/tag/#{tag}")
    end
  end

  defp run_cmd(cmd, args, dir) do
    {output, exit_code} = System.cmd(cmd, args, cd: dir, stderr_to_stdout: true)

    if exit_code != 0 do
      log("Warning: #{cmd} #{Enum.join(args, " ")} failed: #{output}")
    end

    {output, exit_code}
  end

  defp log(message) do
    IO.puts("--> [PackageExtension] #{message}")
  end

  defp copy_extension_files(source, dest) do
    for dir <- [".claude-plugin", "hooks", "agents", "skills"] do
      source_dir = Path.join(source, dir)
      dest_dir = Path.join(dest, dir)

      if File.exists?(source_dir) do
        File.cp_r!(source_dir, dest_dir)
      end
    end
  end

  defp update_command_references(release_dir) do
    # Update hooks.json (needs different escaping for JSON)
    hooks_path = Path.join([release_dir, "hooks", "hooks.json"])

    if File.exists?(hooks_path) do
      update_hooks_json(hooks_path)
    end

    # Update all SKILL.md files
    skills_dir = Path.join(release_dir, "skills")

    if File.exists?(skills_dir) do
      Path.wildcard(Path.join([skills_dir, "**", "SKILL.md"]))
      |> Enum.each(&update_skill_file/1)
    end
  end

  defp update_hooks_json(path) do
    content = File.read!(path)

    # Use ${CLAUDE_PLUGIN_ROOT} for plugin-relative paths
    updated =
      content
      |> String.replace("MIX_ENV=cli mix cli", "${CLAUDE_PLUGIN_ROOT}/bin/#{@binary_name}")

    File.write!(path, updated)
  end

  defp update_skill_file(path) do
    content = File.read!(path)

    updated =
      content
      # Replace the CLI invocation command with plugin-relative path
      |> String.replace("MIX_ENV=cli mix cli", "${CLAUDE_PLUGIN_ROOT}/bin/#{@binary_name}")
      # Replace allowed-tools pattern to allow the plugin-relative binary
      |> String.replace("Bash(mix cli *)", "Bash(${CLAUDE_PLUGIN_ROOT}/bin/#{@binary_name} *)")

    File.write!(path, updated)
  end

  defp binary_name_for_target(target) do
    os =
      case target.os do
        :darwin -> "darwin"
        :linux -> "linux"
        :windows -> "windows"
      end

    arch =
      case target.cpu do
        :aarch64 -> "arm64"
        :x86_64 -> "x64"
      end

    if target.os == :windows do
      "#{@binary_name}-#{os}-#{arch}.exe"
    else
      "#{@binary_name}-#{os}-#{arch}"
    end
  end

  defp create_install_script(extension_dir) do
    script = ~S"""
    #!/bin/bash
    # CodeMySpec CLI Installer
    # Downloads the appropriate binary for your platform from GitHub Releases

    set -e

    REPO="Code-My-Spec/code_my_spec_claude_code_extension"
    BINARY_NAME="cms"
    VERSION="${CMS_VERSION:-latest}"

    # Determine script directory (where extension is installed)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BIN_DIR="$SCRIPT_DIR/bin"

    # Detect OS and architecture
    detect_platform() {
      OS="$(uname -s)"
      ARCH="$(uname -m)"

      case "$OS" in
        Darwin) OS="darwin" ;;
        Linux) OS="linux" ;;
        MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
        *) echo "Unsupported OS: $OS"; exit 1 ;;
      esac

      case "$ARCH" in
        arm64|aarch64) ARCH="arm64" ;;
        x86_64|amd64) ARCH="x64" ;;
        *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
      esac

      if [ "$OS" = "windows" ]; then
        BINARY_FILE="${BINARY_NAME}-${OS}-${ARCH}.exe"
      else
        BINARY_FILE="${BINARY_NAME}-${OS}-${ARCH}"
      fi
    }

    # Get download URL from GitHub releases
    get_download_url() {
      if [ "$VERSION" = "latest" ]; then
        RELEASE_URL="https://api.github.com/repos/${REPO}/releases/latest"
      else
        RELEASE_URL="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"
      fi

      DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep "browser_download_url.*${BINARY_FILE}" | cut -d '"' -f 4)

      if [ -z "$DOWNLOAD_URL" ]; then
        echo "Error: Could not find binary for ${BINARY_FILE}"
        echo "Available binaries at: https://github.com/${REPO}/releases"
        exit 1
      fi
    }

    # Download and install binary
    install_binary() {
      echo "Creating bin directory..."
      mkdir -p "$BIN_DIR"

      echo "Downloading ${BINARY_FILE}..."
      curl -L -o "$BIN_DIR/$BINARY_NAME" "$DOWNLOAD_URL"

      echo "Making binary executable..."
      chmod +x "$BIN_DIR/$BINARY_NAME"
    }

    # Main
    main() {
      echo "CodeMySpec CLI Installer"
      echo "========================"
      echo ""

      detect_platform
      echo "Detected platform: ${OS}-${ARCH}"
      echo "Binary: ${BINARY_FILE}"
      echo ""

      if [ "$1" = "--dry-run" ]; then
        get_download_url
        echo "Would download from: $DOWNLOAD_URL"
        echo "Would install to: $BIN_DIR/$BINARY_NAME"
        exit 0
      fi

      get_download_url
      install_binary

      echo ""
      echo "Installation complete!"
      echo ""
      echo "Binary installed to: $BIN_DIR/$BINARY_NAME"
      echo ""
      echo "To add the extension to Claude Code:"
      echo "  claude extension add $SCRIPT_DIR"
      echo ""
      echo "To verify installation:"
      echo "  $BIN_DIR/$BINARY_NAME --help"
    }

    main "$@"
    """

    script_path = Path.join(extension_dir, "install.sh")
    File.write!(script_path, script)
    File.chmod!(script_path, 0o755)
  end

  defp create_readme(extension_dir) do
    readme = """
    # CodeMySpec - Claude Code Extension

    AI-powered specification-driven development for Phoenix applications.

    ## Installation

    ### 1. Clone this repository

    ```bash
    git clone https://github.com/Code-My-Spec/code_my_spec_claude_code_extension.git
    cd code_my_spec_claude_code_extension
    ```

    ### 2. Run the installer

    ```bash
    ./install.sh
    ```

    This downloads the appropriate binary for your platform.

    ### 3. Add extension to Claude Code

    ```bash
    claude extension add /path/to/code_my_spec_claude_code_extension
    ```

    ## Usage

    The extension provides these skills (slash commands):

    - `/codemyspec:generate-spec [ModuleName]` - Generate a component specification
    - `/codemyspec:generate-code [ModuleName]` - Generate implementation from spec
    - `/codemyspec:generate-test [ModuleName]` - Generate tests from spec
    - `/codemyspec:implement-context [ContextName]` - Generate all components for a context
    - `/codemyspec:spec-context [ContextName]` - Generate specs for all context components

    ## Requirements

    - macOS (Apple Silicon or Intel) or Linux
    - Claude Code CLI

    ## Troubleshooting

    ### macOS security warning

    If macOS blocks the binary, allow it in System Preferences > Security & Privacy.

    ### Permission denied

    ```bash
    chmod +x bin/cms
    ```

    ## License

    MIT
    """

    readme_path = Path.join(extension_dir, "README.md")
    File.write!(readme_path, readme)
  end

  defp create_gitignore(extension_dir) do
    gitignore = """
    # Binary downloaded by install script
    bin/
    """

    gitignore_path = Path.join(extension_dir, ".gitignore")
    File.write!(gitignore_path, gitignore)
  end
end
