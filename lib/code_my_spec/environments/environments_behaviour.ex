defmodule CodeMySpec.Environments.EnvironmentsBehaviour do
  @callback environment_setup_command(map()) :: String.t()
end
