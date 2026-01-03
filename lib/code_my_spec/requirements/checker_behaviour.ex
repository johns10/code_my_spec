defmodule CodeMySpec.Requirements.CheckerBehaviour do
  alias CodeMySpec.Requirements.Requirement
  alias CodeMySpec.Components.Component

  @type requirement_attrs :: %{
          name: String.t(),
          type: atom(),
          description: String.t(),
          checker_module: String.t(),
          satisfied_by: String.t() | nil,
          satisfied: boolean(),
          checked_at: DateTime.t(),
          details: map()
        }

  @callback check(Requirement.requirement_spec(), Component.t(), keyword()) :: requirement_attrs()
end
