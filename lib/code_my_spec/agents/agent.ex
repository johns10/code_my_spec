defmodule CodeMySpec.Agents.Agent do
  use Ecto.Schema
  import Ecto.Changeset
  alias CodeMySpec.Agents.AgentType

  @type t :: %__MODULE__{
          id: term(),
          name: String.t(),
          agent_type: AgentType.t(),
          implementation: atom(),
          config: map()
        }

  embedded_schema do
    field :name, :string
    embeds_one :agent_type, AgentType
    field :implementation, Ecto.Enum, values: [:claude_code]
    field :config, :map, default: %{}
  end

  @doc false
  def changeset(%__MODULE__{} = agent, attrs) do
    agent
    |> cast(attrs, [:name, :implementation, :config])
    |> cast_embed(:agent_type, required: true)
    |> validate_required([:name, :agent_type, :implementation])
  end
end
