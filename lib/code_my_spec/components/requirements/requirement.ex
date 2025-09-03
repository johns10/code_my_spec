defmodule CodeMySpec.Components.Requirements.Requirement do
  @moduledoc """
  Embedded schema representing a component requirement with its satisfaction status.
  Maps to requirement_definition from Registry but includes computed satisfaction state.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type requirement_type ::
          :file_existence
          | :test_status
          | :cross_component
          | :manual_review
          | :dependencies_satisfied
          | :hierarchy

  @type requirement_spec :: %{
          name: atom(),
          checker: module(),
          satisfied_by: module() | nil
        }

  @type t :: %__MODULE__{
          name: atom(),
          type: requirement_type(),
          description: String.t(),
          checker_module: module(),
          satisfied_by: module() | nil,
          satisfied: boolean(),
          checked_at: DateTime.t() | nil,
          details: map()
        }

  schema "requirements" do
    field :name, :string

    field :type, Ecto.Enum,
      values: [
        :file_existence,
        :test_status,
        :cross_component,
        :manual_review,
        :dependencies_satisfied,
        :hierarchy
      ]

    field :description, :string
    field :checker_module, :string
    field :satisfied_by, :string
    field :satisfied, :boolean, default: false
    field :checked_at, :utc_datetime
    field :details, :map, default: %{}

    belongs_to :component, CodeMySpec.Components.Component

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a requirement from a Registry requirement_spec with computed satisfaction status.
  """
  def from_spec(requirement_spec, component_status) do
    checker = requirement_spec.checker
    check_result = checker.check(requirement_spec, component_status)

    %__MODULE__{
      name: Atom.to_string(requirement_spec.name),
      type: infer_type_from_name(requirement_spec.name),
      description: generate_description(requirement_spec.name),
      checker_module: Atom.to_string(requirement_spec.checker),
      satisfied_by:
        if(requirement_spec.satisfied_by,
          do: Atom.to_string(requirement_spec.satisfied_by)
        ),
      satisfied: check_result.satisfied,
      checked_at: DateTime.utc_now(),
      details: check_result.details
    }
  end

  defp infer_type_from_name(:design_file), do: :file_existence
  defp infer_type_from_name(:implementation_file), do: :file_existence
  defp infer_type_from_name(:test_file), do: :file_existence
  defp infer_type_from_name(:tests_passing), do: :test_status
  defp infer_type_from_name(:dependencies_satisfied), do: :dependencies_satisfied
  defp infer_type_from_name(_), do: :manual_review

  defp generate_description(:design_file), do: "Component design documentation exists"
  defp generate_description(:implementation_file), do: "Component implementation file exists"
  defp generate_description(:test_file), do: "Component test file exists"
  defp generate_description(:tests_passing), do: "Component tests are passing"

  defp generate_description(:dependencies_satisfied),
    do: "All component dependencies are satisfied"

  defp generate_description(name), do: "Requirement #{name} is satisfied"

  @doc """
  Changeset for creating a new requirement.
  """
  def changeset(requirement, attrs) do
    requirement
    |> cast(attrs, [
      :name,
      :type,
      :description,
      :checker_module,
      :satisfied_by,
      :satisfied,
      :checked_at,
      :details
    ])
    |> validate_required([:name, :type, :description, :checker_module, :satisfied])
  end

  @doc """
  Changeset for updating requirement satisfaction status.
  """
  def update_changeset(requirement, attrs) do
    requirement
    |> cast(attrs, [:satisfied, :checked_at, :details])
    |> validate_required([:satisfied])
  end

  @doc """
  Returns the requirement name as an atom for pattern matching.
  """
  def name_atom(%__MODULE__{name: name}), do: String.to_existing_atom(name)

  @doc """
  Returns the checker module for requirement validation.
  """
  def checker_module(%__MODULE__{checker_module: module_string}) do
    String.to_existing_atom("Elixir." <> module_string)
  end

  @doc """
  Returns the satisfied_by module if present.
  """
  def satisfied_by_module(%__MODULE__{satisfied_by: nil}), do: nil

  def satisfied_by_module(%__MODULE__{satisfied_by: module_string}) do
    String.to_existing_atom("Elixir." <> module_string)
  end
end
