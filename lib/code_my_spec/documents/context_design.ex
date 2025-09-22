defmodule CodeMySpec.Documents.ContextDesign do
  @moduledoc """
  Embedded schema representing a Phoenix Context Design specification.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :purpose, :string
    field :entity_ownership, :string
    field :scope_integration, :string
    field :public_api, :string
    field :state_management_strategy, :string
    field :execution_flow, :string

    embeds_many :components, ComponentRef, primary_key: false do
      field :module_name, :string
      field :description, :string
      field :table, :map
    end

    field :dependencies, {:array, :string}

    field :other_sections, :map
  end

  def changeset(context_design, attrs, scope \\ nil) do
    context_design
    |> cast(attrs, [
      :purpose,
      :entity_ownership,
      :scope_integration,
      :public_api,
      :state_management_strategy,
      :execution_flow,
      :other_sections,
      :dependencies
    ])
    |> validate_required([:purpose])
    |> cast_embed(:components, with: &component_ref_changeset/2)
    |> validate_dependencies()
    |> maybe_validate_component_existence(scope)
  end

  defp component_ref_changeset(component_ref, attrs) do
    component_ref
    |> cast(attrs, [:module_name, :description, :table])
    |> validate_required([:module_name, :description])
    |> validate_length(:module_name, min: 1, max: 255)
    |> validate_length(:description, min: 1, max: 500)
    |> validate_format(:module_name, ~r/^[A-Z][a-zA-Z0-9_.]*$/,
      message: "must be a valid Elixir module name"
    )
  end

  defp validate_dependencies(changeset) do
    dependencies = get_field(changeset, :dependencies) || []

    invalid_dependencies =
      Enum.reject(dependencies, fn dep ->
        is_binary(dep) and Regex.match?(~r/^[A-Z][a-zA-Z0-9_.]*$/, dep)
      end)

    if Enum.empty?(invalid_dependencies) do
      changeset
    else
      add_error(changeset, :dependencies, "invalid module names: #{Enum.join(invalid_dependencies, ", ")}")
    end
  end

  defp maybe_validate_component_existence(changeset, nil), do: changeset

  defp maybe_validate_component_existence(changeset, scope) do
    components = get_field(changeset, :components) || []

    invalid_components =
      Enum.reject(components, fn component ->
        case CodeMySpec.Components.get_component_by_module_name(scope, component.module_name) do
          %CodeMySpec.Components.Component{} -> true
          nil -> false
        end
      end)

    if Enum.empty?(invalid_components) do
      changeset
    else
      module_names = Enum.map(invalid_components, & &1.module_name)
      add_error(changeset, :components, "components not found: #{Enum.join(module_names, ", ")}")
    end
  end

  def parse_component_string(component_string) do
    case String.split(component_string, ":", parts: 2) do
      [module_name, description] ->
        {:ok, %{module_name: String.trim(module_name), description: String.trim(description)}}

      [module_name] ->
        {:ok, %{module_name: String.trim(module_name), description: nil}}

      _ ->
        {:error, :invalid_format}
    end
  end

  def parse_dependency_string(dependency_string) do
    case String.split(dependency_string, ":", parts: 2) do
      [module_name, description] ->
        {:ok, %{module_name: String.trim(module_name), description: String.trim(description)}}

      [module_name] ->
        {:ok, %{module_name: String.trim(module_name), description: ""}}

      _ ->
        {:error, :invalid_format}
    end
  end
end
