defmodule CodeMySpecCli.Screens.Main do
  @moduledoc """
  Main REPL screen with splash and command prompt.
  """

  alias CodeMySpecCli.Layouts.Root
  alias CodeMySpecCli.Commands.Registry, as: CommandRegistry
  alias CodeMySpecCli.Auth.OAuthClient

  @logo """
          TPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPW
          Q                                                               Q
          Q     ������W ������W ������W �������W���W   ���W��W   ��W      Q
          Q    ��TPPPP]��TPPP��W��TPP��W��TPPPP]����W ����QZ��W ��T]      Q
          Q    ��Q     ��Q   ��Q��Q  ��Q�����W  ��T����T��Q Z����T]       Q
          Q    ��Q     ��Q   ��Q��Q  ��Q��TPP]  ��QZ��T]��Q  Z��T]        Q
          Q    Z������WZ������T]������T]�������W��Q ZP] ��Q   ��Q         Q
          Q     ZPPPPP] ZPPPPP] ZPPPPP] ZPPPPPP]ZP]     ZP]   ZP]         Q
          Q                                                               Q
          Q    ���W   ���W��W   ��W    �������W������W �������W ������W   Q
          Q    ����W ����QZ��W ��T]    ��TPPPP]��TPP��W��TPPPP]��TPPPP]   Q
          Q    ��T����T��Q Z����T]     �������W������T]�����W  ��Q        Q
          Q    ��QZ��T]��Q  Z��T]      ZPPPP��Q��TPPP] ��TPP]  ��Q        Q
          Q    ��Q ZP] ��Q   ��Q       �������Q��Q     �������WZ������W   Q
          Q    ZP]     ZP]   ZP]       ZPPPPPP]ZP]     ZPPPPPP] ZPPPPP]   Q
          Q                                                               Q
          Q              Specification-Driven Development                 Q
          Q                                                               Q
          ZPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP]
  """

  @doc """
  Display the main screen with splash and start the REPL.
  """
  def show do
    Root.clear_screen()

    # Display logo with color
    logo_colored = Owl.Data.tag(@logo, [:red, :bright])
    Owl.IO.puts(logo_colored)

    Owl.IO.puts(["\n", Owl.Data.tag("Welcome to CodeMySpec!", [:cyan, :bright])])
    Owl.IO.puts([Owl.Data.tag("Type /help to see available commands.\n", :faint)])

    # Start the REPL
    repl()
  end

  @doc """
  Main REPL loop - read, eval, print, loop.
  """
  def repl do
    # Show authentication status in prompt
    prompt = build_prompt()

    # Read input
    input = Owl.IO.input(label: prompt) |> String.trim()

    # Skip empty input
    if input != "" do
      # Execute command
      case CommandRegistry.execute(input) do
        :ok ->
          # Command succeeded, continue
          repl()

        :exit ->
          # Exit command was run
          System.halt(0)

        {:error, message} ->
          # Command failed, show error and continue
          Owl.IO.puts(["\n", Owl.Data.tag("Error: #{message}", [:red, :bright]), "\n"])
          repl()
      end
    else
      # Empty input, just show prompt again
      repl()
    end
  end

  defp build_prompt do
    auth_indicator =
      if OAuthClient.authenticated?() do
        Owl.Data.tag("●", :green)
      else
        Owl.Data.tag("○", :red)
      end

    [auth_indicator, " ", Owl.Data.tag("codemyspec>", [:cyan, :bright])]
  end
end
