ExUnit.start(exclude: [:integration])
Ecto.Adapters.SQL.Sandbox.mode(CodeMySpec.Repo, :manual)

# Define mock for environments in tests
Mox.defmock(CodeMySpec.MockEnvironment, for: CodeMySpec.Environments.EnvironmentsBehaviour)
