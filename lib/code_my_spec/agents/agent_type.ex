defmodule CodeMySpec.Agents.AgentType do
  @enforce_keys [:name, :description, :prompt]
  defstruct [:name, :prompt, :description, :implementation, config: %{}, additional_tools: []]

  @type t :: %__MODULE__{
          name: String.t(),
          prompt: String.t(),
          description: String.t(),
          implementation: String.t() | nil,
          config: map(),
          additional_tools: list()
        }
end
