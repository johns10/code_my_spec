defmodule CodeMySpec.ClientUsers do
  @moduledoc """
  The ClientUsers context.

  Manages CLI user authentication credentials.
  ClientUsers are not scoped to accounts - they're global.
  """

  import Ecto.Query, warn: false
  alias CodeMySpec.Repo

  alias CodeMySpec.ClientUsers.ClientUser

  @doc """
  Returns the list of client_users.
  """
  def list_client_users do
    Repo.all(ClientUser)
  end

  @doc """
  Gets a single client_user by ID.
  """
  def get_client_user!(id), do: Repo.get!(ClientUser, id)

  @doc """
  Gets a client_user by email.
  """
  def get_client_user_by_email(email) do
    Repo.get_by(ClientUser, email: email)
  end

  @doc """
  Creates a client_user.
  """
  def create_client_user(attrs) do
    %ClientUser{}
    |> ClientUser.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a client_user.
  """
  def update_client_user(%ClientUser{} = client_user, attrs) do
    client_user
    |> ClientUser.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a client_user.
  """
  def delete_client_user(%ClientUser{} = client_user) do
    Repo.delete(client_user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking client_user changes.
  """
  def change_client_user(%ClientUser{} = client_user, attrs \\ %{}) do
    ClientUser.changeset(client_user, attrs)
  end
end
