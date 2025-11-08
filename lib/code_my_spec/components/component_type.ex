defmodule CodeMySpec.Components.ComponentType do
  @moduledoc """
  Centralized definition of component types used throughout the application.
  This ensures consistency across schemas, validations, and documentation.
  """

  @component_types [
    :genserver,
    :context,
    :coordination_context,
    :schema,
    :repository,
    :task,
    :registry,
    :behaviour,
    :liveview,
    :other
  ]

  @type t ::
          :genserver
          | :context
          | :coordination_context
          | :schema
          | :repository
          | :task
          | :registry
          | :behaviour
          | :liveview
          | :other

  @doc """
  Returns the list of valid component types.
  """
  def values, do: @component_types

  @doc """
  Returns a string with component types joined by forward slashes.
  Useful for documentation and error messages.
  """
  def to_string, do: Enum.join(@component_types, "/")
end