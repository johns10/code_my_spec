defmodule CodeMySpec.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: CodeMySpec.Vault
end
