defmodule CodeMySpec.MCPServers.AnalyticsAdmin.Tools.ListKeyEvents do
  @moduledoc """
  Lists key events for a Google Analytics 4 property.

  Returns information about key events (formerly known as conversions) including
  event names, counting method, and default value. Supports pagination with optional
  page_size and page_token parameters. Requires the user to have connected their
  Google account via OAuth and have access to the specified property.
  """

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias CodeMySpec.Google.Analytics
  alias CodeMySpec.MCPServers.Validators
  alias CodeMySpec.Projects

  schema do
    field(:page_size, :integer, required: false, description: "Maximum number of resources to return (default: 50, max: 200)")
    field(:page_token, :string, required: false, description: "Page token from previous ListKeyEvents call for pagination")
  end

  @impl true
  def execute(params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, property_id} <- get_property_id(scope),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, result} <- Analytics.list_key_events(
             conn,
             "properties/#{property_id}",
             params[:page_size],
             params[:page_token]
           ) do
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
          error_response("Failed to list key events: #{inspect(reason)}")
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

  defp format_response(%{keyEvents: key_events} = result)
       when is_list(key_events) and length(key_events) > 0 do
    text = format_key_events(key_events)

    text = if result.nextPageToken do
      text <> "\n\nNext Page Token: #{result.nextPageToken}\nUse this token to retrieve the next page of results."
    else
      text
    end

    Response.tool()
    |> Response.text(text)
  end

  defp format_response(_response) do
    Response.tool()
    |> Response.text("No key events found for this property.")
  end

  defp format_key_events(key_events) do
    key_events
    |> Enum.map(fn event ->
      """
      Key Event: #{event.eventName || "Unnamed"}
      - Name: #{event.name}
      - Counting Method: #{event.countingMethod || "N/A"}
      - Default Value: #{if event.defaultValue, do: event.defaultValue.numericValue || "N/A", else: "N/A"}
      - Deletable: #{event.deletable || false}
      - Custom: #{event.custom || false}
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
