defmodule CodeMySpec.Sessions.StepBehaviour do
  @moduledoc """
  Behaviour for workflow step modules in session orchestration.
  Each step can generate commands and process their results.
  """
  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Sessions.Session

  @callback get_command(scope :: Scope.t(), session :: Session.t()) ::
              {:ok, Command.t()} | {:error, String.t()}

  @callback handle_result(scope :: Scope.t(), session :: Session.t(), result :: map()) ::
              {:ok, Session.t()} | {:error, String.t(), Session.t()}
end
