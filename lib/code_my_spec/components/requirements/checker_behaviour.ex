defmodule CodeMySpec.Components.Requirements.CheckerBehaviour do
  alias CodeMySpec.Components.Requirements.Requirement
  alias CodeMySpec.Components

  @callback check(Requirement.t(), Components.component_status()) :: 
              {:satisfied, map()} | {:not_satisfied, map()}
end
