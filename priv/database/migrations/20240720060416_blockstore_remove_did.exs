defmodule Hexpds.Database.Migrations.BlockstoreRemoveDid do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      remove :repo_did
    end
  end
end
