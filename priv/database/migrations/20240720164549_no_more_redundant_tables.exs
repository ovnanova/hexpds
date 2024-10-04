defmodule Hexpds.Database.Migrations.NoMoreRedundantTables do
  use Ecto.Migration

  def change do
    # All these tables now belong in per-user SQLite DBs
    drop table(:blocks)
    drop table(:records)
    drop table(:commits)
  end
end
