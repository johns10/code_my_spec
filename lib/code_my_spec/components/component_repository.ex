defmodule CodeMySpec.Components.ComponentRepository do
  import Ecto.Query, warn: false

  alias CodeMySpec.Repo
  alias CodeMySpec.Users.Scope
  alias CodeMySpec.Components.Component

  @spec list_components(Scope.t()) :: [Component.t()]
  def list_components(%Scope{active_project_id: project_id}) do
    Component
    |> where([c], c.project_id == ^project_id)
    |> Repo.all()
  end

  @spec get_component!(Scope.t(), integer()) :: Component.t()
  def get_component!(%Scope{active_project_id: project_id}, id) do
    Component
    |> where([c], c.id == ^id and c.project_id == ^project_id)
    |> Repo.one!()
  end

  @spec get_component(Scope.t(), integer()) :: Component.t() | nil
  def get_component(%Scope{active_project_id: project_id}, id) do
    Component
    |> where([c], c.id == ^id and c.project_id == ^project_id)
    |> Repo.one()
  end

  @spec create_component(Scope.t(), map()) :: {:ok, Component.t()} | {:error, Ecto.Changeset.t()}
  def create_component(%Scope{} = scope, attrs) do
    %Component{}
    |> Component.changeset(attrs, scope)
    |> Repo.insert()
  end

  @spec update_component(Scope.t(), Component.t(), map()) ::
          {:ok, Component.t()} | {:error, Ecto.Changeset.t()}
  def update_component(%Scope{} = scope, %Component{} = component, attrs) do
    component
    |> Component.changeset(attrs, scope)
    |> Repo.update()
  end

  @spec delete_component(Scope.t(), Component.t()) ::
          {:ok, Component.t()} | {:error, Ecto.Changeset.t()}
  def delete_component(%Scope{}, %Component{} = component) do
    Repo.delete(component)
  end

  @spec list_components_with_dependencies(Scope.t()) :: [Component.t()]
  def list_components_with_dependencies(%Scope{active_project_id: project_id}) do
    Component
    |> where([c], c.project_id == ^project_id)
    |> preload([
      :dependencies,
      :dependents,
      :outgoing_dependencies,
      :incoming_dependencies,
      :stories
    ])
    |> Repo.all()
  end

  @spec get_component_with_dependencies(Scope.t(), integer()) :: Component.t() | nil
  def get_component_with_dependencies(%Scope{active_project_id: project_id}, id) do
    Component
    |> where([c], c.id == ^id and c.project_id == ^project_id)
    |> preload([:dependencies, :dependents, :outgoing_dependencies, :incoming_dependencies])
    |> Repo.one()
  end

  @spec get_component_by_module_name(Scope.t(), String.t()) :: Component.t() | nil
  def get_component_by_module_name(%Scope{active_project_id: project_id}, module_name) do
    Component
    |> where([c], c.module_name == ^module_name and c.project_id == ^project_id)
    |> Repo.one()
  end

  @spec list_components_by_type(Scope.t(), atom()) :: [Component.t()]
  def list_components_by_type(%Scope{active_project_id: project_id}, type) do
    Component
    |> where([c], c.type == ^type and c.project_id == ^project_id)
    |> Repo.all()
  end

  @spec search_components_by_name(Scope.t(), String.t()) :: [Component.t()]
  def search_components_by_name(%Scope{active_project_id: project_id}, name_pattern) do
    search_term = "%#{name_pattern}%"

    Component
    |> where([c], c.project_id == ^project_id)
    |> where([c], ilike(c.name, ^search_term))
    |> Repo.all()
  end

  @spec show_architecture(Scope.t()) :: [%{component: Component.t(), depth: integer()}]
  def show_architecture(%Scope{active_project_id: project_id}) do
    root_components =
      Component
      |> where([c], c.project_id == ^project_id)
      |> join(:inner, [c], s in assoc(c, :stories))
      |> distinct([c], c.id)
      |> preload([
        :stories,
        outgoing_dependencies: [
          target_component: [
            outgoing_dependencies: [
              target_component: [
                outgoing_dependencies: [
                  target_component: [
                    outgoing_dependencies: [
                      target_component: [
                        outgoing_dependencies: [
                          target_component: [
                            outgoing_dependencies: [
                              target_component: [
                                outgoing_dependencies: :target_component
                              ]
                            ]
                          ]
                        ]
                      ]
                    ]
                  ]
                ]
              ]
            ]
          ]
        ]
      ])
      |> Repo.all()

    Enum.map(root_components, &%{component: &1, depth: 0})
  end
end
