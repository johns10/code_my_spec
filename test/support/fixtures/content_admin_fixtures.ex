defmodule CodeMySpec.ContentAdminFixtures do
  @moduledoc """
  This module defines test helpers for creating
  ContentAdmin entities for testing validation layer.
  """

  alias CodeMySpec.ContentAdmin.ContentAdmin
  alias CodeMySpec.Repo

  def valid_content_admin_attributes(scope, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    Enum.into(attrs, %{
      raw_content: "# Test Content\n\nThis is test content.",
      processed_content: "<h1>Test Content</h1><p>This is test content.</p>",
      parse_status: :success,
      parse_errors: nil,
      metadata: %{
        "slug" => "test-content-admin-#{unique_id}",
        "content_type" => "blog",
        "title" => "Test Content #{unique_id}",
        "protected" => false
      },
      account_id: scope.active_account_id,
      project_id: scope.active_project_id
    })
  end

  def content_admin_fixture(scope, attrs \\ %{}) do
    %ContentAdmin{}
    |> ContentAdmin.changeset(valid_content_admin_attributes(scope, attrs))
    |> Repo.insert!()
  end

  def success_content_admin_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        parse_status: :success,
        parse_errors: nil
      })

    content_admin_fixture(scope, attrs)
  end

  def error_content_admin_fixture(scope, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        parse_status: :error,
        parse_errors: %{
          "error_type" => "parse_error",
          "message" => "Test parse error #{unique_id}"
        },
        processed_content: nil
      })

    content_admin_fixture(scope, attrs)
  end
end