defmodule CodeMySpec.Environments do
  def environment_setup_command(environment, attrs) do
    get_impl(environment).environment_setup_command(attrs)
  end

  def docs_environment_teardown_command(environment, attrs) do
    get_impl(environment).docs_environment_teardown_command(attrs)
  end

  def cmd(environment, command, args, opts \\ []),
    do: get_impl(environment).cmd(command, args, opts)

  defp get_impl(:vscode),
    do: Application.get_env(:code_my_spec, :vscode_environment, CodeMySpec.Environments.VSCode)

  defp get_impl(:local),
    do: Application.get_env(:code_my_spec, :local_environment, CodeMySpec.Environments.Local)
end
