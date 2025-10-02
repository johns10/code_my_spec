defmodule CodeMySpec.Environments.EnvironmentsBehaviour do
  @moduledoc """
  Behaviour for environment implementations.

  Environments handle both command generation (what to run) and command execution
  (how to run it) for their specific context (VSCode, Local, etc.).
  """

  @callback environment_setup_command(attrs :: map()) :: String.t()
  @callback docs_environment_teardown_command(attrs :: map()) :: String.t()
  @callback code_environment_teardown_command(attrs :: map()) :: String.t()
  @callback cmd(command :: String.t(), args :: [String.t()], opts :: Keyword.t()) ::
              {String.t(), non_neg_integer()}
end
