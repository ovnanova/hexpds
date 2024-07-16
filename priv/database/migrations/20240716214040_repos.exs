defmodule Hexpds.Database.Migrations.Repos do
  use Ecto.Migration

  def change do
    # It would be really nice to have all these things go in per-user dbs later, but ¯\_(ツ)_/¯ for now
    create table(:records) do
      add :path, :string, null: false
      add :did, :string, null: false
      add :cid, :binary, null: false
    end
    create table(:commits) do
      add :seq, :integer, null: false
      add :did, :string, null: false
      add :cid, :binary, null: false
    end
  end
end
