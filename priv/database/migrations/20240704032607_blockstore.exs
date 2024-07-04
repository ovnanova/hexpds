defmodule Hexpds.Database.Migrations.Blockstore do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :key, :string
      add :value, :binary
    end
  end
end
