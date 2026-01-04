defmodule CodeMySpec.Requirements.CheckerBehaviour do
  alias CodeMySpec.Requirements.Requirement
  alias CodeMySpec.Requirements.RequirementDefinition
  alias CodeMySpec.Components.Component
  alias CodeMySpec.Users.Scope

  @callback check(Scope.t(), RequirementDefinition.t(), Component.t(), keyword()) ::
              Requirement.requirement_attrs()
end
