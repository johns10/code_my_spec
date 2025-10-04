defmodule CodeMySpec.ContentFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `CodeMySpec.Content` context.
  """

  alias CodeMySpec.Content.Content
  alias CodeMySpec.Repo

  def valid_content_attributes(project, account, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    Enum.into(attrs, %{
      slug: "test-content-#{unique_id}",
      content_type: "blog",
      raw_content: "# Test Content\n\nThis is test content.",
      project_id: project.id,
      account_id: account.id,
      protected: false,
      parse_status: "pending",
      metadata: %{}
    })
  end

  def content_fixture(project, account, attrs \\ %{}) do
    %Content{}
    |> Content.changeset(valid_content_attributes(project, account, attrs))
    |> Repo.insert!()
  end

  def blog_post_fixture(project, account, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        content_type: "blog",
        raw_content: "# Blog Post\n\nThis is a blog post.",
        meta_title: "Test Blog Post",
        meta_description: "A test blog post for testing purposes"
      })

    content_fixture(project, account, attrs)
  end

  def page_fixture(project, account, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        content_type: "page",
        raw_content: "# Page\n\nThis is a page.",
        meta_title: "Test Page",
        meta_description: "A test page for testing purposes"
      })

    content_fixture(project, account, attrs)
  end

  def landing_page_fixture(project, account, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        content_type: "landing",
        raw_content: "# Landing Page\n\nThis is a landing page.",
        meta_title: "Test Landing Page",
        meta_description: "A test landing page",
        og_title: "Test Landing Page",
        og_description: "A test landing page for testing purposes",
        og_image: "https://example.com/image.jpg"
      })

    content_fixture(project, account, attrs)
  end

  def published_content_fixture(project, account, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        publish_at: DateTime.utc_now() |> DateTime.add(-1, :day),
        parse_status: "success",
        processed_content: "<h1>Test Content</h1><p>This is test content.</p>"
      })

    content_fixture(project, account, attrs)
  end

  def scheduled_content_fixture(project, account, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        publish_at: DateTime.utc_now() |> DateTime.add(1, :day),
        parse_status: "success",
        processed_content: "<h1>Scheduled Content</h1><p>This is scheduled content.</p>"
      })

    content_fixture(project, account, attrs)
  end

  def expired_content_fixture(project, account, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        publish_at: DateTime.utc_now() |> DateTime.add(-7, :day),
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :day),
        parse_status: "success",
        processed_content: "<h1>Expired Content</h1><p>This is expired content.</p>"
      })

    content_fixture(project, account, attrs)
  end

  def protected_content_fixture(project, account, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        protected: true,
        parse_status: "success",
        processed_content: "<h1>Protected Content</h1><p>This is protected content.</p>"
      })

    content_fixture(project, account, attrs)
  end

  def failed_content_fixture(project, account, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        parse_status: "error",
        parse_errors: %{
          "error" => "Processing failed",
          "details" => "Invalid markdown syntax"
        }
      })

    content_fixture(project, account, attrs)
  end
end
