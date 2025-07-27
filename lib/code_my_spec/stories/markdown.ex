defmodule CodeMySpec.Stories.Markdown do
  @moduledoc """
  Handles parsing and formatting of user stories in markdown format for import/export functionality.
  Provides clean separation between markdown processing logic and story domain operations.
  """

  @type story_attrs :: %{
          title: binary(),
          description: binary(),
          acceptance_criteria: [binary()]
        }

  @type format_error :: :invalid_structure | :missing_sections | :malformed_headers
  @type parse_error :: :invalid_format | :empty_document | :missing_story_data

  @spec validate_format(binary()) :: {:ok, :valid} | {:error, format_error()}
  def validate_format(markdown) when is_binary(markdown) do
    markdown
    |> String.trim()
    |> case do
      "" -> {:error, :empty_document}
      content -> check_document_structure(content)
    end
  end

  @spec parse_markdown(binary()) :: {:ok, [story_attrs()]} | {:error, parse_error()}
  def parse_markdown(markdown) when is_binary(markdown) do
    with {:ok, :valid} <- validate_format(markdown),
         sections <- split_into_sections(markdown),
         {:ok, stories} <- parse_story_sections(sections) do
      {:ok, stories}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec format_stories([story_attrs()]) :: binary()
  @spec format_stories([story_attrs()], binary()) :: binary()
  def format_stories(stories, project_name \\ nil)

  def format_stories(stories, nil) when is_list(stories) do
    stories
    |> Enum.map(&format_story_section/1)
    |> Enum.join("\n\n")
  end

  def format_stories(stories, project_name) when is_list(stories) and is_binary(project_name) do
    header = "# #{project_name}\n\n"
    story_sections = 
      stories
      |> Enum.map(&format_story_section/1)
      |> Enum.join("\n\n")
    
    header <> story_sections
  end

  # Private functions

  defp check_document_structure(content) do
    lines = String.split(content, "\n")
    check_section_structure(lines)
  end


  defp check_section_structure(lines) do
    story_headers = Enum.filter(lines, &String.starts_with?(&1, "## "))
    
    case story_headers do
      [] -> {:error, :missing_sections}
      [_ | _] = headers ->
        if Enum.all?(headers, &(byte_size(String.trim(&1)) > 3)) do
          {:ok, :valid}
        else
          {:error, :malformed_headers}
        end
    end
  end

  defp split_into_sections(markdown) do
    sections = String.split(markdown, "\n## ")
    
    case sections do
      [first_section | rest] ->
        # Check if first section contains a story (starts with ## after trimming)
        if String.trim(first_section) |> String.starts_with?("## ") do
          # No project header, all sections are stories
          Enum.map(sections, fn
            "## " <> _ = section -> section
            section -> "## " <> section
          end)
        else
          # Has project header, skip first section
          Enum.map(rest, &("## " <> &1))
        end
      
      [] -> []
    end
  end

  defp parse_story_sections(sections) do
    sections
    |> Enum.reduce_while({:ok, []}, fn section, {:ok, acc} ->
      case parse_story_section(section) do
        {:ok, story} -> {:cont, {:ok, [story | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, stories} -> {:ok, Enum.reverse(stories)}
      error -> error
    end
  end

  defp parse_story_section(section) do
    lines = String.split(section, "\n")
    
    with {:ok, title} <- extract_title(lines),
         {:ok, description} <- extract_description(lines),
         {:ok, criteria} <- extract_acceptance_criteria(lines) do
      {:ok, %{title: title, description: description, acceptance_criteria: criteria}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_title(lines) do
    case Enum.find(lines, &String.starts_with?(&1, "## ")) do
      nil -> {:error, :missing_story_data}
      title_line ->
        title = String.trim_leading(title_line, "## ") |> String.trim()
        if title == "", do: {:error, :missing_story_data}, else: {:ok, title}
    end
  end

  defp extract_description(lines) do
    criteria_index = Enum.find_index(lines, &String.contains?(&1, "**Acceptance Criteria**"))
    title_index = Enum.find_index(lines, &String.starts_with?(&1, "## "))
    
    start_index = (title_index || 0) + 1
    end_index = criteria_index || length(lines)
    
    description =
      lines
      |> Enum.slice(start_index, end_index - start_index)
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.join("\n")
      |> String.trim()
    
    if description == "", do: {:error, :missing_story_data}, else: {:ok, description}
  end

  defp extract_acceptance_criteria(lines) do
    criteria_index = Enum.find_index(lines, &String.contains?(&1, "**Acceptance Criteria**"))
    
    case criteria_index do
      nil -> {:ok, []}
      index ->
        criteria =
          lines
          |> Enum.drop(index + 1)
          |> Enum.filter(&String.starts_with?(&1, "- "))
          |> Enum.map(&String.trim_leading(&1, "- "))
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
        
        {:ok, criteria}
    end
  end

  defp format_story_section(story) do
    title_section = "## #{story.title}"
    description_section = story.description
    
    criteria_section = 
      if length(story.acceptance_criteria) > 0 do
        criteria_list = 
          story.acceptance_criteria
          |> Enum.map(&"- #{&1}")
          |> Enum.join("\n")
        
        "**Acceptance Criteria**\n#{criteria_list}"
      else
        ""
      end
    
    [title_section, description_section, criteria_section]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end
end