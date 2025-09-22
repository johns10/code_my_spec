defmodule CodeMySpec.Environments.Local do
  @behaviour CodeMySpec.Environments.EnvironmentsBehaviour

  def environment_setup_command(%{
        repo_url: repo_url,
        branch_name: branch_name,
        working_dir: working_dir
      }) do
    project_name = extract_project_name(repo_url)

    """
    cd #{working_dir} && \
    git clone #{repo_url} #{project_name} && \
    cd #{project_name} && \
    git switch -C #{branch_name} && \
    mix deps.get
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

  defp extract_project_name(repo_url) do
    repo_url
    |> String.split("/")
    |> List.last()
    |> String.replace(".git", "")
  end
end
