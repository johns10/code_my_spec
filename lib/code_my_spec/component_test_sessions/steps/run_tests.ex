defmodule CodeMySpec.ComponentTestSessions.Steps.RunTests do
  @moduledoc """
  Test execution and quality validation step for component test generation sessions.

  ## Design

  This step runs generated tests and validates their quality through two checks:
  1. Test execution state - ensures all tests are failing (TDD requirement)
  2. Spec alignment - ensures tests match spec assertions (>= 90% alignment)

  ### Quality Requirements
  - Test execution state score: 1.0 (binary - all tests must be failing)
  - Spec alignment score: >= 0.9 (90% of spec assertions implemented)
  - Overall quality score: >= 0.95 (average of both checks)

  ### Success Criteria
  - Tests compile without errors
  - Test runner executes successfully
  - All quality checks pass with scores meeting thresholds

  ### Error Conditions
  - Compilation failures
  - Quality checks fail (tests passing, poor alignment)
  - Malformed test output

  Test assertion failures are EXPECTED in TDD - they're validated by the
  test execution state quality check.
  """

  @behaviour CodeMySpec.Sessions.StepBehaviour

  alias CodeMySpec.Sessions.Command
  alias CodeMySpec.{Quality, Sessions, Utils, Environments}
  require Logger

  @required_alignment_score 0.9
  @required_overall_score 0.95

  def get_command(_scope, %{component: component, project: project}, opts) do
    %{test_file: test_file_path} = Utils.component_files(component, project)

    # Build compile check args
    compile_args = [test_file_path, "--force", "--warnings-as-errors", "--machine"]

    # Build test check args
    base_test_args = ["test", test_file_path, "--formatter", "ExUnitJsonFormatter"]

    test_args =
      case Keyword.get(opts, :seed) do
        nil -> base_test_args
        seed -> base_test_args ++ ["--seed", to_string(seed)]
      end

    # Build checks list
    checks = %{
      compile: %{args: compile_args},
      test: %{args: test_args}
    }

    {:ok, Command.new(__MODULE__, "run_checks", metadata: %{checks: checks})}
  end

  def handle_result(scope, session, result, opts \\ []) do
    # Check compilation first - hard blocker if it fails
    %{component: component, project: project} = session
    %{code_file: code_file_path} = Utils.component_files(component, project)
    implementation_exists = check_implementation_exists(session, code_file_path)
    opts = Keyword.put_new(opts, :tdd_mode, not implementation_exists)
    compile_result = Quality.check_compilation(result)

    if compile_result.score == 0.0 do
      # Compilation errors present - fail immediately
      error_message = format_compilation_errors(compile_result)
      updated_result = update_result_error(scope, result, error_message)
      {:ok, %{}, updated_result}
    else
      # Compilation passed (possibly with warnings) - continue with other checks
      Logger.info(inspect(result))
      tdd_state_result = Quality.check_tdd_state(result)
      alignment_result = Quality.spec_test_alignment(component, project, opts)

      # Calculate overall quality score including all three checks
      overall_score = (compile_result.score + tdd_state_result.score + alignment_result.score) / 3

      # Validate quality thresholds
      case validate_quality(compile_result, tdd_state_result, alignment_result, overall_score) do
        :ok ->
          {:ok, %{}, result}

        {:error, quality_errors} ->
          error_message =
            format_quality_errors(
              quality_errors,
              compile_result,
              tdd_state_result,
              alignment_result,
              overall_score
            )

          updated_result = update_result_error(scope, result, error_message)
          {:ok, %{}, updated_result}
      end
    end
  end

  defp validate_quality(compile_result, tdd_state_result, alignment_result, overall_score) do
    errors = []

    # Check compilation warnings (errors already handled as hard blocker)
    errors =
      if compile_result.score < 1.0 do
        errors ++ compile_result.errors
      else
        errors
      end

    # Check TDD state
    errors =
      if tdd_state_result.score < 1.0 do
        errors ++ tdd_state_result.errors
      else
        errors
      end

    # Check alignment
    errors =
      if alignment_result.score < @required_alignment_score do
        alignment_error = """
        Test alignment score (#{Float.round(alignment_result.score, 2)}) is below required threshold (#{@required_alignment_score}).
        Tests must be at least 90% aligned with spec assertions.
        """

        errors ++ [alignment_error | alignment_result.errors]
      else
        errors
      end

    # Check overall score
    errors =
      if overall_score < @required_overall_score do
        overall_error = """
        Overall quality score (#{Float.round(overall_score, 2)}) is below required threshold (#{@required_overall_score}).
        """

        errors ++ [overall_error]
      else
        errors
      end

    if Enum.empty?(errors) do
      :ok
    else
      {:error, errors}
    end
  end

  defp format_compilation_errors(compile_result) do
    """
    Compilation failed:

    #{Enum.map_join(compile_result.errors, "\n", fn error -> "#{String.trim(error)}" end)}
    """
  end

  defp format_quality_errors(
         errors,
         compile_result,
         tdd_state_result,
         alignment_result,
         overall_score
       ) do
    """
    Quality checks failed:

    Compilation Score: #{compile_result.score}
    TDD State Score: #{tdd_state_result.score}
    Alignment Score: #{Float.round(alignment_result.score, 2)}
    Overall Score: #{Float.round(overall_score, 2)} (required: >= #{@required_overall_score})

    Errors:
    #{Enum.map_join(errors, "\n", fn error -> "- #{String.trim(error)}" end)}
    """
  end

  defp update_result_error(scope, result, error_message) do
    attrs = %{status: :error, error_message: error_message}

    case Sessions.update_result(scope, result, attrs) do
      {:ok, updated} ->
        updated

      {:error, changeset} ->
        Logger.error("#{__MODULE__} failed to update result", changeset: changeset)
        result
    end
  end

  defp check_implementation_exists(session, code_file_path) do
    # Create environment to check file existence
    {:ok, environment} = Environments.create(session.environment)
    CodeMySpec.Environments.file_exists?(environment, code_file_path)
  end
end
