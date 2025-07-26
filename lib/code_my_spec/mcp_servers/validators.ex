defmodule CodeMySpec.MCPServers.Validators do
  @moduledoc """
  Validation functions for MCP servers.
  """

  @doc """
  Validates that the current scope has an active account set.
  Returns {:ok, frame} if valid, {:stop, :missing_active_account} if not.
  """
  def require_active_account(frame) do
    frame.assigns
    |> Map.get(:current_scope)
    |> case do
      nil -> nil
      scope -> Map.get(scope, :active_account)
    end
    |> case do
      nil -> {:error, :missing_active_account}
      _account -> {:ok, frame}
    end
  end

  @doc """
  Validates that the current scope has an active project set.
  Returns {:ok, frame} if valid, {:stop, :missing_active_project} if not.
  """
  def require_active_project(frame) do
    frame.assigns
    |> Map.get(:current_scope)
    |> case do
      nil -> nil
      scope -> Map.get(scope, :active_project)
    end
    |> case do
      nil -> {:error, :missing_active_project}
      _project -> {:ok, frame}
    end
  end

  def validate_scope(frame) do
    with {:ok, frame} <- require_active_account(frame),
         {:ok, frame} <- require_active_project(frame) do
      {:ok, frame.assigns.current_scope}
    end
  end
end
