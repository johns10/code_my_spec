defmodule CodeMySpec.ContentSync.HeexProcessorTest do
  use ExUnit.Case, async: true

  alias CodeMySpec.ContentSync.HeexProcessor

  # ============================================================================
  # Fixtures - Valid HEEx Templates
  # ============================================================================

  defp valid_minimal_heex do
    """
    <div>Hello World</div>
    """
  end

  defp valid_simple_heex_with_assigns do
    """
    <div>
      <p><%= @name %></p>
    </div>
    """
  end

  defp valid_heex_with_components do
    """
    <div>
      <.button type="primary">Click me</.button>
      <.card title="Welcome">
        <p>Content here</p>
      </.card>
    </div>
    """
  end

  defp valid_heex_with_multiple_assigns do
    """
    <article>
      <h1><%= @title %></h1>
      <p class="meta">By <%= @author %> on <%= @date %></p>
      <div class="content">
        <%= @body %>
      </div>
    </article>
    """
  end

  defp valid_heex_with_conditionals do
    """
    <div>
      <%= if @show_header do %>
        <header>
          <h1><%= @title %></h1>
        </header>
      <% end %>

      <%= unless @hide_content do %>
        <div class="content">
          <%= @content %>
        </div>
      <% end %>
    </div>
    """
  end

  defp valid_heex_with_for_comprehension do
    """
    <ul>
      <%= for item <- @items do %>
        <li><%= item.name %></li>
      <% end %>
    </ul>
    """
  end

  defp valid_heex_with_case_statement do
    """
    <div>
      <%= case @status do %>
        <% :active -> %>
          <span class="badge-green">Active</span>
        <% :inactive -> %>
          <span class="badge-gray">Inactive</span>
        <% _ -> %>
          <span class="badge-red">Unknown</span>
      <% end %>
    </div>
    """
  end

  defp valid_heex_with_nested_components do
    """
    <.modal>
      <.card>
        <.header>
          <h2><%= @title %></h2>
        </.header>
        <.body>
          <p><%= @content %></p>
        </.body>
      </.card>
    </.modal>
    """
  end

  defp valid_heex_with_attributes do
    """
    <div class="container" id={@container_id} data-role="main">
      <button type="button" disabled={@is_disabled} phx-click="submit">
        Submit
      </button>
      <input type="text" value={@value} placeholder="Enter text" />
    </div>
    """
  end

  defp valid_heex_with_dynamic_attributes do
    """
    <div {@dynamic_attrs}>
      <button {%{"data-id" => @id, "class" => @classes}}>
        Click
      </button>
    </div>
    """
  end

  defp valid_heex_with_slots do
    """
    <.layout>
      <:header>
        <h1>Page Title</h1>
      </:header>
      <:main>
        <p>Main content</p>
      </:main>
      <:footer>
        <p>Footer content</p>
      </:footer>
    </.layout>
    """
  end

  defp valid_heex_with_string_interpolation do
    ~S"""
    <div>
      <p>Hello, <%= @name %>!</p>
      <p>You have <%= @count %> messages.</p>
      <a href={"/users/#{@user_id}"}>Profile</a>
    </div>
    """
  end

  defp valid_heex_with_comments do
    """
    <div>
      <%!-- This is a HEEx comment --%>
      <p>Visible content</p>
      <%!--
        Multi-line
        comment
      --%>
    </div>
    """
  end

  defp valid_heex_with_html5_elements do
    """
    <article>
      <header>
        <h1>Article Title</h1>
        <time datetime="2025-01-15">January 15, 2025</time>
      </header>
      <section>
        <p>Article content</p>
      </section>
      <footer>
        <p>Author info</p>
      </footer>
    </article>
    """
  end

  defp valid_heex_with_forms do
    """
    <form phx-submit="save">
      <label for="name">Name:</label>
      <input type="text" id="name" name="name" value={@name} />

      <label for="email">Email:</label>
      <input type="email" id="email" name="email" value={@email} />

      <button type="submit">Save</button>
    </form>
    """
  end

  defp valid_heex_with_phx_events do
    """
    <div>
      <button phx-click="increment">+</button>
      <span><%= @count %></span>
      <button phx-click="decrement">-</button>

      <input type="text" phx-change="update" phx-debounce="300" />

      <div id="chart" phx-hook="Chart" data-values={@values}></div>
    </div>
    """
  end

  defp valid_heex_with_special_characters do
    """
    <div>
      <p>&lt;script&gt; tags are escaped</p>
      <p>Ampersands &amp; work fine</p>
      <p>Less than &lt; and greater than &gt;</p>
      <p>Copyright &copy; 2025</p>
    </div>
    """
  end

  defp valid_heex_with_unicode do
    """
    <div>
      <p>测试内容 - Chinese</p>
      <p>café résumé - Accents</p>
      <p>🚀 💻 🎉 - Emojis</p>
      <p>Математика - Cyrillic</p>
    </div>
    """
  end

  defp valid_heex_empty do
    ""
  end

  defp valid_heex_whitespace_only do
    """


    """
  end

  # ============================================================================
  # Fixtures - Invalid HEEx Templates (Syntax Errors)
  # ============================================================================

  defp invalid_heex_unclosed_tag do
    """
    <div>
      <p>Unclosed paragraph
    </div>
    """
  end

  defp invalid_heex_mismatched_tags do
    """
    <div>
      <p>Content</span>
    </div>
    """
  end

  defp invalid_heex_unclosed_eex do
    """
    <div>
      <%= @name
    </div>
    """
  end

  defp invalid_heex_unclosed_component do
    """
    <div>
      <.button>Click me
    </div>
    """
  end

  defp invalid_heex_invalid_eex_syntax do
    """
    <div>
      <%= for item <-< @items do %>
        <p><%= item %></p>
      <% end %>
    </div>
    """
  end

  defp invalid_heex_malformed_component do
    """
    <div>
      <.>Invalid component name</.>
    </div>
    """
  end

  defp invalid_heex_unclosed_slot do
    """
    <.layout>
      <:header>
        <h1>Title</h1>
    </.layout>
    """
  end

  defp invalid_heex_invalid_attribute_syntax do
    """
    <div class=@class>
      Content
    </div>
    """
  end

  defp invalid_heex_unclosed_comprehension do
    """
    <ul>
      <%= for item <- @items do %>
        <li><%= item %></li>
    </ul>
    """
  end

  defp invalid_heex_unclosed_conditional do
    """
    <div>
      <%= if @show do %>
        <p>Content</p>
    </div>
    """
  end

  defp invalid_heex_unclosed_case do
    """
    <div>
      <%= case @status do %>
        <% :active -> %>
          <span>Active</span>
    </div>
    """
  end

  defp invalid_heex_missing_end do
    """
    <div>
      <%= if @condition do %>
        <p>Content</p>
      <% else %>
        <p>Other content</p>
    </div>
    """
  end

  defp invalid_heex_bad_slot_syntax do
    """
    <.card>
      <header>This should be a slot</:header>
    </.card>
    """
  end

  defp invalid_heex_nested_unclosed_tags do
    """
    <div>
      <section>
        <article>
          <p>Content
        </article>
      </section>
    """
  end

  # ============================================================================
  # Fixtures - Complex Valid Templates
  # ============================================================================

  defp complex_heex_blog_post do
    """
    <article class="blog-post">
      <header>
        <h1><%= @post.title %></h1>
        <div class="meta">
          <time datetime={@post.published_at}>
            <%= format_date(@post.published_at) %>
          </time>
          <span>By <%= @post.author.name %></span>
        </div>
      </header>

      <div class="content">
        <%= raw(@post.body) %>
      </div>

      <%= if @post.tags != [] do %>
        <div class="tags">
          <%= for tag <- @post.tags do %>
            <.tag_badge name={tag.name} color={tag.color} />
          <% end %>
        </div>
      <% end %>

      <footer>
        <.share_buttons post_id={@post.id} />

        <%= if @current_user do %>
          <.comment_form post_id={@post.id} user={@current_user} />
        <% else %>
          <p>
            <a href="/login">Log in</a> to comment
          </p>
        <% end %>
      </footer>
    </article>
    """
  end

  defp complex_heex_form_with_validation do
    """
    <.form for={@changeset} phx-change="validate" phx-submit="save">
      <div class="form-group">
        <.input
          field={@changeset[:name]}
          label="Name"
          required
          placeholder="Enter your name"
        />
        <%= if error = @changeset.errors[:name] do %>
          <.error message={elem(error, 0)} />
        <% end %>
      </div>

      <div class="form-group">
        <.input
          field={@changeset[:email]}
          type="email"
          label="Email"
        />
      </div>

      <%= if @changeset.valid? do %>
        <.button type="submit">Save</.button>
      <% else %>
        <.button type="button" disabled>Save</.button>
      <% end %>
    </.form>
    """
  end

  defp complex_heex_dashboard do
    """
    <div class="dashboard">
      <.header>
        <h1>Dashboard</h1>
        <.breadcrumbs items={@breadcrumbs} />
      </.header>

      <div class="stats-grid">
        <%= for stat <- @stats do %>
          <.stat_card
            title={stat.title}
            value={stat.value}
            change={stat.change}
            trend={stat.trend}
          />
        <% end %>
      </div>

      <.section title="Recent Activity">
        <.table rows={@activities}>
          <:col :let={activity} label="Action">
            <%= activity.action %>
          </:col>
          <:col :let={activity} label="User">
            <%= activity.user.name %>
          </:col>
          <:col :let={activity} label="Time">
            <%= format_time(activity.inserted_at) %>
          </:col>
        </.table>
      </.section>
    </div>
    """
  end

  # ============================================================================
  # process/1 - Valid HEEx Tests
  # ============================================================================

  describe "process/1 - minimal valid heex" do
    test "successfully validates simple HEEx template" do
      assert {:ok, result} = HeexProcessor.process(valid_minimal_heex())
      assert result.parse_status == :success
      assert result.raw_content == valid_minimal_heex()
      assert is_nil(result.processed_content)
      assert is_nil(result.parse_errors)
    end

    test "returns ProcessorResult struct with all required fields" do
      assert {:ok, result} = HeexProcessor.process(valid_minimal_heex())
      assert is_map(result)
      assert Map.has_key?(result, :raw_content)
      assert Map.has_key?(result, :processed_content)
      assert Map.has_key?(result, :parse_status)
      assert Map.has_key?(result, :parse_errors)
    end

    test "processed_content is always nil for valid templates" do
      assert {:ok, result} = HeexProcessor.process(valid_minimal_heex())
      assert is_nil(result.processed_content)
    end
  end

  describe "process/1 - heex with assigns" do
    test "successfully validates HEEx with simple assigns" do
      assert {:ok, result} = HeexProcessor.process(valid_simple_heex_with_assigns())
      assert result.parse_status == :success
      assert result.raw_content == valid_simple_heex_with_assigns()
      assert is_nil(result.processed_content)
    end

    test "successfully validates HEEx with multiple assigns" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_multiple_assigns())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "@title")
      assert String.contains?(result.raw_content, "@author")
      assert String.contains?(result.raw_content, "@body")
    end

    test "successfully validates HEEx with string interpolation" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_string_interpolation())
      assert result.parse_status == :success
    end
  end

  describe "process/1 - heex with components" do
    test "successfully validates HEEx with function components" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_components())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "<.button")
      assert String.contains?(result.raw_content, "<.card")
    end

    test "successfully validates HEEx with nested components" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_nested_components())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "<.modal>")
      assert String.contains?(result.raw_content, "<.card>")
    end

    test "successfully validates HEEx with slots" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_slots())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "<:header>")
      assert String.contains?(result.raw_content, "<:main>")
      assert String.contains?(result.raw_content, "<:footer>")
    end
  end

  describe "process/1 - heex with control flow" do
    test "successfully validates HEEx with conditionals" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_conditionals())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "if @show_header")
      assert String.contains?(result.raw_content, "unless @hide_content")
    end

    test "successfully validates HEEx with for comprehension" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_for_comprehension())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "for item <- @items")
    end

    test "successfully validates HEEx with case statement" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_case_statement())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "case @status")
    end
  end

  describe "process/1 - heex with attributes" do
    test "successfully validates HEEx with static attributes" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_attributes())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "class=\"container\"")
    end

    test "successfully validates HEEx with dynamic attributes" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_dynamic_attributes())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "{@dynamic_attrs}")
    end

    test "successfully validates HEEx with boolean attributes" do
      heex = """
      <button disabled={@is_disabled} required>
        Submit
      </button>
      """

      assert {:ok, result} = HeexProcessor.process(heex)
      assert result.parse_status == :success
    end
  end

  describe "process/1 - heex with phoenix features" do
    test "successfully validates HEEx with phx-click events" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_phx_events())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "phx-click")
    end

    test "successfully validates HEEx with phx-change events" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_phx_events())
      assert String.contains?(result.raw_content, "phx-change")
    end

    test "successfully validates HEEx with phx-submit on forms" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_forms())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "phx-submit")
    end

    test "successfully validates HEEx with phx-hooks" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_phx_events())
      assert String.contains?(result.raw_content, "phx-hook")
    end
  end

  describe "process/1 - heex with standard html" do
    test "successfully validates HEEx with HTML5 semantic elements" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_html5_elements())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "<article>")
      assert String.contains?(result.raw_content, "<section>")
    end

    test "successfully validates HEEx with forms" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_forms())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "<form")
      assert String.contains?(result.raw_content, "<input")
    end

    test "successfully validates HEEx with comments" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_comments())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "<%!--")
    end
  end

  describe "process/1 - heex with special content" do
    test "successfully validates HEEx with HTML entities" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_special_characters())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "&lt;")
      assert String.contains?(result.raw_content, "&amp;")
    end

    test "successfully validates HEEx with unicode characters" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_with_unicode())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "测试")
      assert String.contains?(result.raw_content, "café")
      assert String.contains?(result.raw_content, "🚀")
    end
  end

  describe "process/1 - empty and whitespace heex" do
    test "successfully validates empty HEEx template" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_empty())
      assert result.parse_status == :success
      assert result.raw_content == ""
      assert is_nil(result.processed_content)
    end

    test "successfully validates whitespace-only HEEx template" do
      assert {:ok, result} = HeexProcessor.process(valid_heex_whitespace_only())
      assert result.parse_status == :success
      assert is_nil(result.processed_content)
    end
  end

  # ============================================================================
  # process/1 - Invalid HEEx Tests (Syntax Errors)
  # ============================================================================

  describe "process/1 - unclosed tags" do
    test "returns error for unclosed HTML tag" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_tag())
      assert result.parse_status == :error
      assert result.raw_content == invalid_heex_unclosed_tag()
      assert is_nil(result.processed_content)
      assert not is_nil(result.parse_errors)
    end

    test "error includes details for unclosed tag" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_tag())
      assert is_map(result.parse_errors)
      assert Map.has_key?(result.parse_errors, :error_type)
      assert Map.has_key?(result.parse_errors, :message)
      assert is_binary(result.parse_errors.error_type)
      assert is_binary(result.parse_errors.message)
    end
  end

  describe "process/1 - mismatched tags" do
    test "returns error for mismatched HTML tags" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_mismatched_tags())
      assert result.parse_status == :error
      assert is_nil(result.processed_content)
      assert not is_nil(result.parse_errors)
    end
  end

  describe "process/1 - unclosed eex expressions" do
    test "returns error for unclosed EEx expression" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_eex())
      assert result.parse_status == :error
      assert result.raw_content == invalid_heex_unclosed_eex()
      assert is_nil(result.processed_content)
    end

    test "error includes line number when available" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_eex())
      # Line number may or may not be present depending on error type
      assert is_map(result.parse_errors)
    end
  end

  describe "process/1 - component syntax errors" do
    test "returns error for unclosed component" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_component())
      assert result.parse_status == :error
      assert is_nil(result.processed_content)
    end

    test "returns error for malformed component name" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_malformed_component())
      assert result.parse_status == :error
      assert not is_nil(result.parse_errors)
    end
  end

  describe "process/1 - slot syntax errors" do
    test "returns error for unclosed slot" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_slot())
      assert result.parse_status == :error
      assert is_nil(result.processed_content)
    end

    test "returns error for bad slot syntax" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_bad_slot_syntax())
      assert result.parse_status == :error
      assert not is_nil(result.parse_errors)
    end
  end

  describe "process/1 - attribute syntax errors" do
    test "returns error for invalid attribute syntax" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_invalid_attribute_syntax())
      assert result.parse_status == :error
      assert is_nil(result.processed_content)
    end
  end

  describe "process/1 - control flow syntax errors" do
    test "returns error for unclosed for comprehension" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_comprehension())
      assert result.parse_status == :error
      assert not is_nil(result.parse_errors)
    end

    test "returns error for unclosed if conditional" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_conditional())
      assert result.parse_status == :error
      assert is_nil(result.processed_content)
    end

    test "returns error for unclosed case statement" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_case())
      assert result.parse_status == :error
      assert not is_nil(result.parse_errors)
    end

    test "returns error for missing end keyword" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_missing_end())
      assert result.parse_status == :error
      assert is_nil(result.processed_content)
    end
  end

  describe "process/1 - invalid eex syntax" do
    test "returns error for invalid EEx syntax" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_invalid_eex_syntax())
      assert result.parse_status == :error
      assert not is_nil(result.parse_errors)
    end
  end

  describe "process/1 - complex syntax errors" do
    test "returns error for nested unclosed tags" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_nested_unclosed_tags())
      assert result.parse_status == :error
      assert result.raw_content == invalid_heex_nested_unclosed_tags()
      assert is_nil(result.processed_content)
    end
  end

  # ============================================================================
  # process/1 - Error Structure Tests
  # ============================================================================

  describe "process/1 - error structure validation" do
    test "error result has consistent structure" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_eex())
      assert result.parse_status == :error
      assert is_map(result.parse_errors)
      assert Map.has_key?(result.parse_errors, :error_type)
      assert Map.has_key?(result.parse_errors, :message)
    end

    test "error_type is a string" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_tag())
      assert is_binary(result.parse_errors.error_type)
    end

    test "message is a human-readable string" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_eex())
      assert is_binary(result.parse_errors.message)
      assert String.length(result.parse_errors.message) > 0
    end

    test "line number included when available" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_eex())
      # Line may or may not be present, but if it is, it should be an integer
      if Map.has_key?(result.parse_errors, :line) do
        assert is_integer(result.parse_errors.line)
        assert result.parse_errors.line > 0
      end
    end

    test "column number included when available" do
      assert {:ok, result} = HeexProcessor.process(invalid_heex_unclosed_tag())
      # Column may or may not be present, but if it is, it should be an integer
      if Map.has_key?(result.parse_errors, :column) do
        assert is_integer(result.parse_errors.column)
        assert result.parse_errors.column >= 0
      end
    end
  end

  # ============================================================================
  # process/1 - Complex Valid Templates
  # ============================================================================

  describe "process/1 - complex real-world templates" do
    test "successfully validates complex blog post template" do
      assert {:ok, result} = HeexProcessor.process(complex_heex_blog_post())
      assert result.parse_status == :success
      assert is_nil(result.processed_content)
      assert String.contains?(result.raw_content, "@post.title")
      assert String.contains?(result.raw_content, "<.tag_badge")
    end

    test "successfully validates complex form with validation" do
      assert {:ok, result} = HeexProcessor.process(complex_heex_form_with_validation())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "@changeset")
      assert String.contains?(result.raw_content, "phx-change")
    end

    test "successfully validates complex dashboard template" do
      assert {:ok, result} = HeexProcessor.process(complex_heex_dashboard())
      assert result.parse_status == :success
      assert String.contains?(result.raw_content, "<.table")
      assert String.contains?(result.raw_content, ":let={activity}")
    end
  end

  # ============================================================================
  # process/1 - Edge Cases
  # ============================================================================

  describe "process/1 - edge cases" do
    test "handles very long HEEx template" do
      long_template =
        "<div>" <>
          Enum.map_join(1..1000, "", fn i ->
            "<p><%= @item_#{i} %></p>"
          end) <> "</div>"

      assert {:ok, result} = HeexProcessor.process(long_template)
      assert result.parse_status == :success
      assert String.length(result.raw_content) > 10_000
    end

    test "handles deeply nested components" do
      nested =
        Enum.reduce(1..20, "<p>Deep content</p>", fn _, acc ->
          "<.wrapper>#{acc}</.wrapper>"
        end)

      assert {:ok, result} = HeexProcessor.process(nested)
      assert result.parse_status == :success
    end

    test "handles template with many assigns" do
      template =
        "<div>" <>
          Enum.map_join(1..100, "", fn i ->
            "<span><%= @var_#{i} %></span>"
          end) <> "</div>"

      assert {:ok, result} = HeexProcessor.process(template)
      assert result.parse_status == :success
    end

    test "handles mixed line endings" do
      heex = "<div>\r\n<p><%= @content %></p>\n</div>\r\n"

      assert {:ok, result} = HeexProcessor.process(heex)
      assert result.parse_status == :success
    end

    test "handles template with only comments" do
      heex = """
      <%!-- Comment 1 --%>
      <%!-- Comment 2 --%>
      """

      assert {:ok, result} = HeexProcessor.process(heex)
      assert result.parse_status == :success
    end

    test "handles self-closing HTML tags" do
      heex = """
      <div>
        <img src="/image.jpg" />
        <br />
        <hr />
        <input type="text" />
      </div>
      """

      assert {:ok, result} = HeexProcessor.process(heex)
      assert result.parse_status == :success
    end
  end

  # ============================================================================
  # process/1 - Consistency Tests
  # ============================================================================

  describe "process/1 - consistency properties" do
    test "processing same template multiple times returns identical results" do
      heex = valid_heex_with_components()
      {:ok, result1} = HeexProcessor.process(heex)
      {:ok, result2} = HeexProcessor.process(heex)
      {:ok, result3} = HeexProcessor.process(heex)

      assert result1 == result2
      assert result2 == result3
    end

    test "success results always have nil processed_content" do
      templates = [
        valid_minimal_heex(),
        valid_heex_with_components(),
        valid_heex_with_conditionals(),
        complex_heex_blog_post()
      ]

      for template <- templates do
        {:ok, result} = HeexProcessor.process(template)

        if result.parse_status == :success do
          assert is_nil(result.processed_content)
        end
      end
    end

    test "error results always have nil processed_content" do
      templates = [
        invalid_heex_unclosed_tag(),
        invalid_heex_unclosed_eex(),
        invalid_heex_mismatched_tags(),
        invalid_heex_unclosed_component()
      ]

      for template <- templates do
        {:ok, result} = HeexProcessor.process(template)

        if result.parse_status == :error do
          assert is_nil(result.processed_content)
        end
      end
    end

    test "always returns ok tuple regardless of parse status" do
      test_cases = [
        valid_minimal_heex(),
        valid_simple_heex_with_assigns(),
        invalid_heex_unclosed_tag(),
        invalid_heex_unclosed_eex(),
        valid_heex_empty()
      ]

      for test_case <- test_cases do
        assert {:ok, _result} = HeexProcessor.process(test_case)
      end
    end

    test "raw_content is always preserved exactly" do
      templates = [
        valid_minimal_heex(),
        invalid_heex_unclosed_tag(),
        valid_heex_with_unicode()
      ]

      for template <- templates do
        {:ok, result} = HeexProcessor.process(template)
        assert result.raw_content == template
      end
    end
  end

  # ============================================================================
  # process/1 - Security Considerations
  # ============================================================================

  describe "process/1 - security considerations" do
    test "validates without executing JavaScript in template" do
      heex = """
      <script>alert('This should not execute');</script>
      <p><%= @content %></p>
      """

      assert {:ok, result} = HeexProcessor.process(heex)
      # Validation should complete without executing any code
      assert result.parse_status in [:success, :error]
    end

    test "validates without executing onclick handlers" do
      heex = """
      <button onclick="alert('xss')"><%= @label %></button>
      """

      assert {:ok, result} = HeexProcessor.process(heex)
      assert result.parse_status in [:success, :error]
    end

    test "safely handles template with dangerous EEx code" do
      heex = """
      <div>
        <%= System.cmd("ls", []) %>
      </div>
      """

      assert {:ok, result} = HeexProcessor.process(heex)
      # Compilation should succeed without executing the command
      assert result.parse_status in [:success, :error]
    end

    test "does not render template during validation" do
      # This template would fail at render time but should validate
      heex = """
      <div>
        <%= @nonexistent_assign %>
        <%= @another_missing_assign %>
      </div>
      """

      assert {:ok, result} = HeexProcessor.process(heex)
      # Should succeed because we only validate syntax, not render
      assert result.parse_status == :success
    end
  end

  # ============================================================================
  # process/1 - Real World Examples
  # ============================================================================

  describe "process/1 - real world examples" do
    test "validates typical Phoenix LiveView template" do
      heex = """
      <div class="container">
        <h1><%= @page_title %></h1>

        <%= if @current_user do %>
          <p>Welcome, <%= @current_user.name %>!</p>
        <% else %>
          <.link href="/login">Sign in</.link>
        <% end %>

        <.live_component
          module={MyAppWeb.UserListComponent}
          id="user-list"
          users={@users}
        />
      </div>
      """

      assert {:ok, result} = HeexProcessor.process(heex)
      assert result.parse_status == :success
    end

    test "validates e-commerce product listing template" do
      heex = """
      <div class="products">
        <%= for product <- @products do %>
          <.product_card product={product}>
            <:header>
              <h3><%= product.name %></h3>
              <span class="price">$<%= product.price %></span>
            </:header>
            <:body>
              <img src={product.image_url} alt={product.name} />
              <p><%= product.description %></p>
            </:body>
            <:footer>
              <button phx-click="add_to_cart" phx-value-id={product.id}>
                Add to Cart
              </button>
            </:footer>
          </.product_card>
        <% end %>
      </div>
      """

      assert {:ok, result} = HeexProcessor.process(heex)
      assert result.parse_status == :success
    end

    test "validates admin dashboard with tables template" do
      heex = """
      <div class="admin-dashboard">
        <h1>User Management</h1>

        <.table id="users" rows={@users}>
          <:col :let={user} label="ID"><%= user.id %></:col>
          <:col :let={user} label="Name"><%= user.name %></:col>
          <:col :let={user} label="Email"><%= user.email %></:col>
          <:col :let={user} label="Status">
            <%= case user.status do %>
              <% :active -> %> <.badge color="green">Active</.badge>
              <% :suspended -> %> <.badge color="red">Suspended</.badge>
              <% _ -> %> <.badge color="gray">Unknown</.badge>
            <% end %>
          </:col>
          <:action :let={user}>
            <.button phx-click="edit" phx-value-id={user.id}>Edit</.button>
            <.button phx-click="delete" phx-value-id={user.id} color="red">
              Delete
            </.button>
          </:action>
        </.table>
      </div>
      """

      assert {:ok, result} = HeexProcessor.process(heex)
      assert result.parse_status == :success
    end
  end
end
