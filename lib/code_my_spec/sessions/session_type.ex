defmodule CodeMySpec.Sessions.SessionType do
  use Ecto.Type

  @type t :: CodeMySpec.ContextDesignSessions

  @valid_types [CodeMySpec.ContextDesignSessions]

  @spec type() :: :string
  def type, do: :string

  @spec cast(binary() | atom()) :: {:ok, t()} | :error

  def cast(module) when is_atom(module) and module in @valid_types do
    {:ok, module}
  end

  def cast(string) when is_binary(string) do
    Keyword.get(mapper(), String.to_atom(string))
    |> cast
  end

  def cast(_module), do: :error

  @spec load(binary()) :: {:ok, t()} | :error
  def load(data) when is_binary(data), do: {:ok, String.to_atom(data)}

  @spec dump(atom()) :: {:ok, binary()} | :error
  def dump(module) when is_atom(module), do: {:ok, Atom.to_string(module)}
  def dump(_), do: :error

  def mapper() do
    Enum.map(@valid_types, fn type ->
      {type |> Atom.to_string() |> String.split(".") |> List.last() |> String.to_atom(), type}
    end)
  end
end
