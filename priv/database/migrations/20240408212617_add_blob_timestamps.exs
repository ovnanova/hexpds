defmodule Hexpds.Database.Migrations.AddBlobTimestamps do
  use Ecto.Migration

  def change do
    alter table(:blobs) do
      timestamps()
    end
  end
end
