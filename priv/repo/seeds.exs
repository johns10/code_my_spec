# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     CodeMySpec.Repo.insert!(%CodeMySpec.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Create OAuth2 application for MCP connector
import Ecto.Query

# Create MCP client application directly with Ecto
secret = "mcp_secret_#{:crypto.strong_rand_bytes(32) |> Base.encode64()}"

# Check if app already exists
existing_app =
  CodeMySpec.Repo.one(
    from a in "oauth_applications",
      where: a.uid == "claude-mcp-connector",
      select: %{uid: a.uid, secret: a.secret}
  )

if !existing_app do
  # Insert new OAuth application
  {1, [_mcp_app]} =
    CodeMySpec.Repo.insert_all(
      "oauth_applications",
      [
        %{
          name: "Claude MCP Connector",
          uid: "claude-mcp-connector",
          secret: secret,
          redirect_uri: "https://claude.ai/oauth/callback",
          scopes: "read write stories:read stories:write projects:read",
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      ],
      returning: [:uid, :secret]
    )
end
