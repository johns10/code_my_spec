defmodule CodeMySpec.Agents.AgentType do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          prompt: String.t(),
          description: String.t(),
          implementation: String.t() | nil,
          config: map(),
          additional_tools: [String.t()]
        }

  @primary_key false
  embedded_schema do
    field :name, :string
    field :prompt, :string
    field :description, :string
    field :implementation, :string
    field :config, :map, default: %{}
    field :additional_tools, {:array, :string}, default: []
  end

  def changeset(agent_type, attrs) do
    agent_type
    |> cast(attrs, [:name, :prompt, :description, :implementation, :config, :additional_tools])
    |> validate_required([:name, :prompt, :description])
  end
end
