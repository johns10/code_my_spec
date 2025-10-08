defmodule CodeMySpecWeb.PageController do
  use CodeMySpecWeb, :controller

  def home(conn, _params) do
    render(conn, :home, copy: CodeMySpecWeb.PageHTML.home_copy())
  end
end
