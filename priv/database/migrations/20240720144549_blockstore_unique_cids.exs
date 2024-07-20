defmodule Hexpds.Database.Migrations.BlockstoreUniqueCids do
  use Ecto.Migration

  def change do
    create unique_index(:blocks, :block_cid)
  end
end
