defmodule CodeMySpec.Agents.Agent do
  use Ecto.Schema
  import Ecto.Changeset
  alias CodeMySpec.Agents.AgentType

  @type t :: %__MODULE__{
          id: term(),
          name: String.t(),
          agent_type: AgentType.t(),
          config: map(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  embedded_schema do
    field :name, :string
    embeds_one :agent_type, AgentType
    field :config, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(%__MODULE__{} = agent, attrs) do
    agent
    |> cast(attrs, [:name, :config])
    |> cast_embed(:agent_type, required: true)
    |> validate_required([:name, :agent_type])
  end
end
