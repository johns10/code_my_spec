defmodule CodeMySpec.Environments.VSCode do
  @behaviour CodeMySpec.Environments.EnvironmentsBehaviour

  def environment_setup_command(%{branch_name: _branch_name, working_dir: _working_dir}) do
    """
    """
  end

  def docs_environment_teardown_command(%{
        context_name: context_name,
        working_dir: working_dir,
        design_file_name: design_file_name,
        branch_name: branch_name
      }) do
    """
    git -C #{working_dir} add #{design_file_name} && \
    git -C #{working_dir} commit -m "created context design for #{context_name}" && \
    git -C #{working_dir} switch main && \
    git -C #{working_dir} merge #{branch_name}
    """
  end

  def test_environment_teardown_command(%{
        working_dir: working_dir,
        test_file_name: test_file_name
      }) do
    """
    git -C #{working_dir} add #{test_file_name}
    """
  end

  def code_environment_teardown_command(%{
        context_name: _context_name,
        working_dir: working_dir,
        code_file_name: code_file_name,
        test_file_name: _test_file_name,
        branch_name: _branch_name
      }) do
    """
    git -C #{working_dir} add #{code_file_name}
    """
  end

  def cmd(_command, _args, _opts), do: {"not_impl", 1}
end
