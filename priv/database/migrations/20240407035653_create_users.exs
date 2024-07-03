defmodule Hexpds.Database.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :did, :string
      add :handle, :string
      add :password_hash, :string
      add :signing_key, :binary
      add :rotation_key, :binary
      add :data, :map
    end

    create unique_index(:users, [:did])
    create unique_index(:users, [:handle])
  end
end
