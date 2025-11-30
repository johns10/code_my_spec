defmodule CodeMySpec.ClientUsersTest do
  use CodeMySpec.DataCase

  alias CodeMySpec.ClientUsers

  describe "client_users" do
    alias CodeMySpec.ClientUsers.ClientUser

    import CodeMySpec.ClientUsersFixtures

    @invalid_attrs %{email: nil, oauth_token: nil}

    test "list_client_users/0 returns all client_users" do
      client_user = client_user_fixture()
      assert ClientUsers.list_client_users() == [client_user]
    end

    test "get_client_user!/1 returns the client_user with given id" do
      client_user = client_user_fixture()
      assert ClientUsers.get_client_user!(client_user.id) == client_user
    end

    test "get_client_user_by_email/1 returns the client_user with given email" do
      client_user = client_user_fixture()
      assert ClientUsers.get_client_user_by_email(client_user.email) == client_user
    end

    test "create_client_user/1 with valid data creates a client_user" do
      valid_attrs = %{
        id: 123,
        email: "test@example.com",
        oauth_token: "some oauth_token",
        oauth_refresh_token: "some oauth_refresh_token",
        oauth_expires_at: ~U[2025-11-27 22:18:00Z]
      }

      assert {:ok, %ClientUser{} = client_user} = ClientUsers.create_client_user(valid_attrs)
      assert client_user.email == "test@example.com"
      # Tokens are encrypted, so we can't directly compare them
      assert client_user.oauth_token != nil
      assert client_user.oauth_refresh_token != nil
      assert client_user.oauth_expires_at == ~U[2025-11-27 22:18:00Z]
    end

    test "create_client_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ClientUsers.create_client_user(@invalid_attrs)
    end

    test "create_client_user/1 with duplicate email returns error" do
      client_user = client_user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               ClientUsers.create_client_user(%{
                 email: client_user.email,
                 oauth_token: "token"
               })
    end

    test "update_client_user/2 with valid data updates the client_user" do
      client_user = client_user_fixture()

      update_attrs = %{
        email: "updated@example.com",
        oauth_token: "updated token",
        oauth_refresh_token: "updated refresh",
        oauth_expires_at: ~U[2025-11-28 22:18:00Z]
      }

      assert {:ok, %ClientUser{} = updated} =
               ClientUsers.update_client_user(client_user, update_attrs)

      assert updated.email == "updated@example.com"
      assert updated.oauth_expires_at == ~U[2025-11-28 22:18:00Z]
    end

    test "update_client_user/2 with invalid data returns error changeset" do
      client_user = client_user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               ClientUsers.update_client_user(client_user, @invalid_attrs)

      assert client_user == ClientUsers.get_client_user!(client_user.id)
    end

    test "delete_client_user/1 deletes the client_user" do
      client_user = client_user_fixture()
      assert {:ok, %ClientUser{}} = ClientUsers.delete_client_user(client_user)
      assert_raise Ecto.NoResultsError, fn -> ClientUsers.get_client_user!(client_user.id) end
    end

    test "change_client_user/1 returns a client_user changeset" do
      client_user = client_user_fixture()
      assert %Ecto.Changeset{} = ClientUsers.change_client_user(client_user)
    end
  end
end
