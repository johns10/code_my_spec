defmodule CodeMySpecCli.Screens.Main do
  @moduledoc """
  Main screen with splash screen and navigation menu.
  """

  alias CodeMySpecCli.Layouts.Root
  alias CodeMySpecCli.Components.Navigation

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
  Display the main screen with splash and menu.
  """
  def show do
    Root.clear_screen()

    # Display logo with color
    logo_colored = Owl.Data.tag(@logo, [:red, :bright])
    Owl.IO.puts(logo_colored)

    # Show menu
    show_menu()
  end

  @doc """
  Show the navigation menu.
  """
  def show_menu do
    Owl.IO.puts("\n")

    options = [
      {"Generate Project", :generate},
      {"Run Tests", :test},
      {"View Stories", :stories},
      {"Settings", :settings},
      {"Exit", :exit}
    ]

    selected = Navigation.menu(options, title: "What would you like to do?")

    handle_selection(selected)
  end

  defp handle_selection({_label, :exit}) do
    Owl.IO.puts(["\n", Owl.Data.tag("Goodbye! 👋", :green)])
    System.halt(0)
  end

  defp handle_selection({label, action}) do
    Owl.IO.puts(["\n", Owl.Data.tag("You selected: #{label}", :yellow)])
    Owl.IO.puts([Owl.Data.tag("Action: #{action} (not yet implemented)", :cyan)])

    # Wait for user to press enter
    Owl.IO.puts(["\n", Owl.Data.tag("Press Enter to continue...", :dim)])
    IO.gets("")

    # Return to menu
    show()
  end
end
