defmodule CodeMySpec.Specs do
  @moduledoc """
  Coordinate parsing of spec files following the format defined in `docs/new_spec_format.md` into structured embedded schemas.
  """

  alias CodeMySpec.Specs.SpecParser

  defdelegate parse(file_path), to: SpecParser
  defdelegate from_markdown(markdown_content), to: SpecParser
end