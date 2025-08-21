defmodule CodeMySpec.Components.Requirements.CheckerBehaviour do
  alias CodeMySpec.Components.Registry

  @callback check(Registry.requirement_definition(), Registry.component_status()) ::
              {:satisfied, map()} | {:not_satisfied, map()}
end
