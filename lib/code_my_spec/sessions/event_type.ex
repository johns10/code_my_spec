defmodule CodeMySpec.Sessions.EventType do
  @moduledoc """
  Custom Ecto type for SessionEvent event_type that handles camelCase to snake_case conversion.

  This allows clients to send event types in camelCase (e.g., "proxyRequest")
  while storing them as snake_case atoms (e.g., :proxy_request) in the database.
  """

  use Ecto.Type

  @valid_types [
    :proxy_request,
    :proxy_response,
    :session_start,
    :notification_hook,
    :session_stop_hook,
    :post_tool_use,
    :user_prompt_submit,
    :stop
  ]

  def type, do: :string

  @doc """
  Casts input from client (string or atom) to internal atom format.
  Handles both camelCase and snake_case input.
  """
  def cast(value) when is_binary(value) do
    value
    |> Recase.to_snake()
    |> String.to_existing_atom()
    |> validate_type()
  rescue
    ArgumentError ->
      # If atom doesn't exist, try creating it and validating
      value
      |> Recase.to_snake()
      |> String.to_atom()
      |> validate_type()
  end

  def cast(value) when is_atom(value) do
    validate_type(value)
  end

  def cast(_), do: :error

  @doc """
  Loads data from the database (converts string to atom).
  """
  def load(value) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> :error
  end

  def load(_), do: :error

  @doc """
  Dumps data to the database (converts atom to string).
  """
  def dump(value) when is_atom(value) do
    if value in @valid_types do
      {:ok, Atom.to_string(value)}
    else
      :error
    end
  end

  def dump(_), do: :error

  # Validates that the type is in the allowed list
  defp validate_type(value) when value in @valid_types, do: {:ok, value}
  defp validate_type(_), do: :error
end
