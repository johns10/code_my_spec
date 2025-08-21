defmodule CodeMySpec.Tests.CommandBuilderTest do
  use ExUnit.Case
  doctest CodeMySpec.Tests.CommandBuilder
  alias CodeMySpec.Tests.CommandBuilder

  describe "build_command/1" do
    test "returns base command with no options" do
      assert CommandBuilder.build_command([]) == "mix test --formatter ExUnitJsonFormatter"
    end

    test "includes tags" do
      result = CommandBuilder.build_command(include: [:integration, :slow])
      assert result == "mix test --formatter ExUnitJsonFormatter --include integration,slow"
    end

    test "excludes tags" do
      result = CommandBuilder.build_command(exclude: [:pending, :external])
      assert result == "mix test --formatter ExUnitJsonFormatter --exclude pending,external"
    end

    test "sets seed" do
      result = CommandBuilder.build_command(seed: 12345)
      assert result == "mix test --formatter ExUnitJsonFormatter --seed 12345"
    end

    test "sets max failures" do
      result = CommandBuilder.build_command(max_failures: 5)
      assert result == "mix test --formatter ExUnitJsonFormatter --max-failures 5"
    end

    test "includes only specific files" do
      result = CommandBuilder.build_command(only: ["test/user_test.exs:42", "test/account_test.exs"])
      assert result == "mix test --formatter ExUnitJsonFormatter --only test/user_test.exs:42 --only test/account_test.exs"
    end

    test "includes stale flag" do
      result = CommandBuilder.build_command(stale: true)
      assert result == "mix test --formatter ExUnitJsonFormatter --stale"
    end

    test "includes failed flag" do
      result = CommandBuilder.build_command(failed: true)
      assert result == "mix test --formatter ExUnitJsonFormatter --failed"
    end

    test "includes trace flag" do
      result = CommandBuilder.build_command(trace: true)
      assert result == "mix test --formatter ExUnitJsonFormatter --trace"
    end

    test "ignores false boolean flags" do
      result = CommandBuilder.build_command(stale: false, failed: false, trace: false)
      assert result == "mix test --formatter ExUnitJsonFormatter"
    end

    test "combines multiple options" do
      result = CommandBuilder.build_command([
        include: [:integration],
        exclude: [:slow],
        seed: 42,
        max_failures: 3,
        stale: true
      ])
      
      assert result == "mix test --formatter ExUnitJsonFormatter --include integration --exclude slow --seed 42 --max-failures 3 --stale"
    end

    test "ignores unknown options" do
      result = CommandBuilder.build_command(unknown_option: "value")
      assert result == "mix test --formatter ExUnitJsonFormatter"
    end

    test "ignores invalid numeric values" do
      result = CommandBuilder.build_command(seed: 0, max_failures: -1)
      assert result == "mix test --formatter ExUnitJsonFormatter"
    end
  end

  describe "validate_opts/1" do
    test "returns :ok for valid options" do
      assert CommandBuilder.validate_opts([
        include: [:integration],
        exclude: [:slow],
        seed: 42,
        max_failures: 5,
        stale: true,
        failed: false,
        trace: true
      ]) == :ok
    end

    test "returns error for conflicting include/exclude tags" do
      result = CommandBuilder.validate_opts(include: [:slow], exclude: [:slow])
      assert {:error, error_msg} = result
      assert error_msg =~ "Conflicting include/exclude tags"
      assert error_msg =~ "[:slow]"
    end

    test "returns error for invalid seed" do
      assert {:error, "Invalid seed: 0 (must be positive integer)"} = 
        CommandBuilder.validate_opts(seed: 0)
      
      assert {:error, "Invalid seed: \"invalid\" (must be positive integer)"} = 
        CommandBuilder.validate_opts(seed: "invalid")
    end

    test "returns error for invalid max_failures" do
      assert {:error, "Invalid max_failures: -1 (must be positive integer)"} = 
        CommandBuilder.validate_opts(max_failures: -1)
    end

    test "returns error for invalid boolean options" do
      assert {:error, "Invalid stale: \"yes\" (must be boolean)"} = 
        CommandBuilder.validate_opts(stale: "yes")
      
      assert {:error, "Invalid failed: 1 (must be boolean)"} = 
        CommandBuilder.validate_opts(failed: 1)

      assert {:error, "Invalid trace: \"on\" (must be boolean)"} = 
        CommandBuilder.validate_opts(trace: "on")
    end

    test "allows nil values for all options" do
      assert CommandBuilder.validate_opts([
        include: nil,
        exclude: nil,
        seed: nil,
        max_failures: nil,
        stale: nil,
        failed: nil,
        trace: nil
      ]) == :ok
    end
  end
end
