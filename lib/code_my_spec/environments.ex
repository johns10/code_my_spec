defmodule CodeMySpec.Environments do
  def environment_setup_command(environment, attrs) do
    get_impl(environment).environment_setup_command(attrs)
  end

  def docs_environment_teardown_command(environment, attrs) do
    get_impl(environment).docs_environment_teardown_command(attrs)
  end

  def get_impl(:vscode), do: CodeMySpec.Environments.VSCode
  def get_impl(:local), do: CodeMySpec.Environments.Local
end
