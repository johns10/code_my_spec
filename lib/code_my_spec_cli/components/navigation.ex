defmodule CodeMySpecCli.Components.Navigation do
  @moduledoc """
  Navigation component with arrow key support and enter to select.
  """

  @doc """
  Displays a menu with options and handles navigation.
  Returns the selected option.

  Options should be a list of tuples: [{label, value}, ...]
  """
  def menu(options, opts \\ []) do
    title = Keyword.get(opts, :title, "Select an option")

    # Convert options to the format Owl expects: just a list of labels
    labels = Enum.map(options, fn {label, _value} -> label end)

    # Get the selected label
    selected_label = Owl.IO.select(labels, label: title)

    # Find the original option tuple that matches the selected label
    Enum.find(options, fn {label, _value} -> label == selected_label end)
  end
end
