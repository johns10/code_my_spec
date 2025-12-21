defmodule CodeMySpec.Sessions.CommandModuleType do
  use Ecto.Type
  require Logger

  @valid_modules [
    CodeMySpec.ContextSpecSessions.Steps.Initialize,
    CodeMySpec.ContextSpecSessions.Steps.GenerateContextDesign,
    CodeMySpec.ContextSpecSessions.Steps.ValidateDesign,
    CodeMySpec.ContextSpecSessions.Steps.ReviseDesign,
    CodeMySpec.ContextSpecSessions.Steps.Finalize,
    CodeMySpec.ContextComponentsDesignSessions.Steps.Initialize,
    CodeMySpec.ContextComponentsDesignSessions.Steps.SpawnComponentDesignSessions,
    CodeMySpec.ContextComponentsDesignSessions.Steps.SpawnReviewSession,
    CodeMySpec.ContextComponentsDesignSessions.Steps.Finalize,
    CodeMySpec.ContextCodingSessions.Steps.Initialize,
    CodeMySpec.ContextCodingSessions.Steps.SpawnComponentCodingSessions,
    CodeMySpec.ContextCodingSessions.Steps.Finalize,
    CodeMySpec.ContextTestingSessions.Steps.Initialize,
    CodeMySpec.ContextTestingSessions.Steps.SpawnComponentTestingSessions,
    CodeMySpec.ContextTestingSessions.Steps.Finalize,
    CodeMySpec.ContextDesignReviewSessions.Steps.ExecuteReview,
    CodeMySpec.ContextDesignReviewSessions.Steps.Finalize,
    CodeMySpec.ComponentDesignSessions.Steps.Initialize,
    CodeMySpec.ComponentDesignSessions.Steps.GenerateComponentDesign,
    CodeMySpec.ComponentDesignSessions.Steps.ValidateDesign,
    CodeMySpec.ComponentDesignSessions.Steps.ReviseDesign,
    CodeMySpec.ComponentDesignSessions.Steps.Finalize,
    CodeMySpec.ComponentCodingSessions.Steps.Initialize,
    CodeMySpec.ComponentCodingSessions.Steps.GenerateImplementation,
    CodeMySpec.ComponentCodingSessions.Steps.RunTests,
    CodeMySpec.ComponentCodingSessions.Steps.FixTestFailures,
    CodeMySpec.ComponentCodingSessions.Steps.Finalize,
    CodeMySpec.ComponentTestSessions.Steps.Initialize,
    CodeMySpec.ComponentTestSessions.Steps.GenerateTestsAndFixtures,
    CodeMySpec.ComponentTestSessions.Steps.RunTests,
    CodeMySpec.ComponentTestSessions.Steps.FixCompilationErrors,
    CodeMySpec.ComponentTestSessions.Steps.Finalize
  ]

  def type, do: :string

  def cast(module) when is_atom(module) do
    {:ok, module}
  end

  def cast(string) when is_binary(string) do
    Map.get(string_mapper(), string)
    |> cast
  end

  def cast(_), do: :error

  def load(data) when is_binary(data) do
    {:ok, Map.get(string_mapper(), data)}
  end

  def dump(module) when is_atom(module) do
    {:ok, Atom.to_string(module)}
  end

  def dump(_), do: :error

  def string_mapper() do
    Enum.reduce(@valid_modules, %{}, fn type, acc ->
      Map.put(acc, type |> Atom.to_string(), type)
    end)
  end
end
