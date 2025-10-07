ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(CodeMySpec.Repo, :manual)

# Define mock for environments in tests
Mox.defmock(CodeMySpec.MockEnvironment, for: CodeMySpec.Environments.EnvironmentsBehaviour)

# Define mock for Git operations in tests
Mox.defmock(CodeMySpec.MockGit, for: CodeMySpec.Git.Behaviour)

# Initialize test fixture repository
CodeMySpec.Support.TestAdapter.ensure_fixture_fresh()
