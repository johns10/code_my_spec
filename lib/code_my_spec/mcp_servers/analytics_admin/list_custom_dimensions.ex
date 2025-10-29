defmodule CodeMySpec.MCPServers.AnalyticsAdmin.Tools.ListCustomDimensions do
  @moduledoc """
  Lists custom dimensions for a Google Analytics 4 property.

  Returns information about custom dimensions including names, display names,
  parameter names, and scope. Requires the user to have connected their Google
  account via OAuth and have access to the specified property.
  """

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias CodeMySpec.Google.Analytics
  alias CodeMySpec.MCPServers.Validators
  alias CodeMySpec.Projects

  schema do
  end

  @impl true
  def execute(_params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, property_id} <- get_property_id(scope),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, result} <- Analytics.list_custom_dimensions(conn, "properties/#{property_id}") do
        format_response(result)
      else
        {:error, :not_found} ->
          error_response(
            "Google account not connected. Please connect your Google account first."
          )

        {:error, :token_expired} ->
          error_response("Google access token has expired. Please reconnect your Google account.")

        {:error, :missing_property_id} ->
          error_response(
            "Google Analytics Property ID is not set for this project. Please update the project settings."
          )

        {:error, reason} ->
          error_response("Failed to list custom dimensions: #{inspect(reason)}")
      end

    {:reply, response, frame}
  end

  defp get_property_id(scope) do
    case scope.active_project.google_analytics_property_id do
      nil -> {:error, :missing_property_id}
      "" -> {:error, :missing_property_id}
      property_id -> {:ok, property_id}
    end
  end

  defp format_response(%{customDimensions: dimensions})
       when is_list(dimensions) and length(dimensions) > 0 do
    Response.tool()
    |> Response.text(format_dimensions(dimensions))
  end

  defp format_response(_response) do
    Response.tool()
    |> Response.text("No custom dimensions found for this property.")
  end

  defp format_dimensions(dimensions) do
    dimensions
    |> Enum.map(fn dimension ->
      """
      Custom Dimension: #{dimension.displayName || "Unnamed"}
      - Name: #{dimension.name}
      - Parameter Name: #{dimension.parameterName}
      - Scope: #{dimension.scope || "N/A"}
      - Description: #{dimension.description || "No description"}
      """
    end)
    |> Enum.join("\n")
  end

  defp error_response(message) when is_binary(message) do
    Response.tool()
    |> Response.error(message)
  end

  defp error_response(error) when is_atom(error) do
    error |> to_string() |> error_response()
  end
end
