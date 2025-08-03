defmodule CodeMySpec.Stories.StoriesRepository do
  import Ecto.Query, warn: false

  alias CodeMySpec.Projects.Project
  alias CodeMySpec.Accounts.Account
  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Stories.Story

  def list_stories(%Scope{} = scope) do
    Repo.all_by(Story, account_id: scope.active_account.id)
  end

  def list_project_stories(%Scope{} = scope) do
    Repo.all_by(Story, project_id: scope.active_project.id)
  end

  def list_unsatisfied_stories(%Scope{} = scope) do
    from(s in Story,
      where: s.project_id == ^scope.active_project.id and is_nil(s.component_id)
    )
    |> Repo.all()
  end

  def get_story(%Scope{} = scope, id) do
    Repo.get_by(Story, id: id, account_id: scope.active_account.id)
  end

  def get_story!(%Scope{} = scope, id) do
    Repo.get_by!(Story, id: id, account_id: scope.active_account.id)
  end

  def create_story(
        %Scope{active_project: %Project{id: project_id}, active_account: %Account{id: account_id}} =
          scope,
        attrs
      ) do
    %Story{}
    |> Story.changeset(attrs)
    |> Ecto.Changeset.put_change(:project_id, project_id)
    |> Ecto.Changeset.put_change(:account_id, account_id)
    |> PaperTrail.insert(originator: scope.user)
    |> case do
      {:ok, %{model: story}} -> {:ok, story}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def create_story(%Scope{} = scope, attrs) do
    %Story{}
    |> Story.changeset(attrs)
    |> PaperTrail.insert(originator: scope.user)
    |> case do
      {:ok, %{model: story}} -> {:ok, story}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def update_story(%Scope{} = scope, %Story{} = story, attrs) do
    story
    |> Story.changeset(attrs)
    |> PaperTrail.update(originator: scope.user)
    |> case do
      {:ok, %{model: story}} -> {:ok, story}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete_story(%Scope{} = scope, %Story{} = story) do
    case PaperTrail.delete(story, originator: scope.user) do
      {:ok, %{model: story}} -> {:ok, story}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def by_project(query \\ Story, project_id) do
    from(s in query, where: s.project_id == ^project_id)
  end

  def by_status(query \\ Story, status) do
    from(s in query, where: s.status == ^status)
  end

  def by_component_priority(query \\ Story, min_priority) do
    from(s in query,
      join: c in assoc(s, :component),
      where: c.priority >= ^min_priority
    )
  end

  def search_text(query \\ Story, text) do
    search_term = "%#{text}%"

    from(s in query,
      where: ilike(s.title, ^search_term) or ilike(s.description, ^search_term)
    )
  end

  def locked_by(query \\ Story, user_id) do
    from(s in query, where: s.locked_by == ^user_id)
  end

  def lock_expired(query \\ Story) do
    from(s in query,
      where: not is_nil(s.lock_expires_at) and s.lock_expires_at < ^DateTime.utc_now()
    )
  end

  def ordered_by_name(query \\ Story) do
    from(s in query, order_by: [asc: s.title])
  end

  def ordered_by_status(query \\ Story) do
    from(s in query, order_by: [asc: s.status, asc: s.inserted_at])
  end

  def paginate(query, page, per_page) do
    offset = (page - 1) * per_page
    from(s in query, limit: ^per_page, offset: ^offset)
  end

  def with_preloads(query, preloads) do
    from(s in query, preload: ^preloads)
  end

  def acquire_lock(%Scope{} = scope, %Story{} = story, expires_in_minutes \\ 30) do
    lock_expires_at = DateTime.utc_now() |> DateTime.add(expires_in_minutes * 60, :second)

    attrs = %{
      locked_by: scope.user.id,
      locked_at: DateTime.utc_now(),
      lock_expires_at: lock_expires_at
    }

    case is_locked?(story) do
      true -> {:error, :already_locked}
      false -> update_lock_fields(story, attrs)
    end
  end

  def release_lock(%Scope{}, %Story{} = story) do
    attrs = %{
      locked_by: nil,
      locked_at: nil,
      lock_expires_at: nil
    }

    update_lock_fields(story, attrs)
  end

  def extend_lock(%Scope{} = scope, %Story{} = story, expires_in_minutes \\ 30) do
    lock_expires_at = DateTime.utc_now() |> DateTime.add(expires_in_minutes * 60, :second)

    case lock_owner(story) == scope.user.id do
      true -> update_lock_fields(story, %{lock_expires_at: lock_expires_at})
      false -> {:error, :not_lock_owner}
    end
  end

  def is_locked?(%Story{} = story) do
    not is_nil(story.locked_by) and
      not is_nil(story.lock_expires_at) and
      DateTime.compare(story.lock_expires_at, DateTime.utc_now()) == :gt
  end

  def lock_owner(%Story{} = story) do
    story.locked_by
  end

  def set_story_component(%Scope{} = scope, %Story{} = story, component_id) do
    story
    |> Story.changeset(%{component_id: component_id})
    |> PaperTrail.update(originator: scope.user)
    |> case do
      {:ok, %{model: story}} -> {:ok, story}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def clear_story_component(%Scope{} = scope, %Story{} = story) do
    story
    |> Story.changeset(%{component_id: nil})
    |> PaperTrail.update(originator: scope.user)
    |> case do
      {:ok, %{model: story}} -> {:ok, story}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # Private function for lock operations that don't need audit trail
  defp update_lock_fields(%Story{} = story, attrs) do
    story
    |> Story.lock_changeset(attrs)
    |> Repo.update()
  end
end
