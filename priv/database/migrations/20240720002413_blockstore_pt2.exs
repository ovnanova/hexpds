defmodule Hexpds.Database.Migrations.BlockstorePt2 do
  use Ecto.Migration

  def change do
    drop table(:blocks)
    create table(:blocks) do
      add :block_cid, :string
      add :repo_did, :string
      add :block_value, :binary
    end
  end
end
