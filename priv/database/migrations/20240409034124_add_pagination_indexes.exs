defmodule Hexpds.Database.Migrations.AddPaginationIndexes do
  use Ecto.Migration

  def change do
    create index(:blobs, [:inserted_at, :id])
  end
end
