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
    embeds_one :agent_type, AgentType, on_replace: :update
    field :implementation, Ecto.Enum, values: [:claude_code]
    field :config, :map, default: %{}
  end

  @doc false
  def changeset(%__MODULE__{} = agent, attrs) do
    agent_type = Map.get(attrs, :agent_type, %AgentType{})

    agent
    |> cast(attrs, [:name, :implementation, :config])
    |> put_embed(:agent_type, agent_type)
    |> validate_required([:name, :agent_type, :implementation])
  end
end
