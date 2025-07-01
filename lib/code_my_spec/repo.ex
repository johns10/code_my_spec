defmodule CodeMySpec.Repo do
  use Ecto.Repo,
    otp_app: :code_my_spec,
    adapter: Ecto.Adapters.Postgres
end
