defmodule Hexpds.Database.Migrations.CreateBlobs do
  use Ecto.Migration

  def change do
    create table(:blobs) do
      add :hash, :binary
      add :cid, :string
      add :mime_type, :string
      add :data, :binary
      add :did, :string
    end
    create unique_index(:blobs, [:hash])
    create index(:blobs, [:did])
    create index(:blobs, [:cid])
  end
end
