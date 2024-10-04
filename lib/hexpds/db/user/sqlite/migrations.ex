defmodule Hexpds.User.Sqlite.Migrations.Macros do
  defmacro migration(migration_name, do: change_block) do
    # need to satisfy my DSL addiction - sj
    quote do
      @migrations __MODULE__.unquote(migration_name)
      defmodule unquote(migration_name) do
        use Ecto.Migration

        def change do
          unquote(change_block)
        end
      end
    end
  end
end

defmodule Hexpds.User.Sqlite.Migrations do
  Module.register_attribute(__MODULE__, :migrations, accumulate: true)

  import __MODULE__.Macros

  migration SetupBlockstore do
    create table(:blocks) do
      add(:block_cid, :string, primary_key: true, null: false)
      add(:block_value, :binary, null: false)

      timestamps() # Maybe will be helpful if we do special sync APIs
    end
  end

  migration CommitsAndRecords do
    create table(:commits) do
      add :seq, :integer, primary_key: true, null: false
      add :cid, :string, null: false

      timestamps() # Probably not strictly necessary, but why not? Better safe than sorry, can easily remove later
    end
    create table(:records) do
      add :record_path, :text, primary_key: true, null: false
      add :collection, :string, null: false
      add :record_cid, :string, null: false

      timestamps() # Will help with sorting for e.g. listRecords
    end
  end

  migration MstNodes do
    # Have probably gotten some of this wrong and may need to change implementation
    create table(:mst_nodes) do
      add :cid, :string, primary_key: true, null: false
      add :left, :string, comment: "CID link, optional: link to sub-tree Node on a lower level and with all keys sorting before keys at this node"
      add :parent_node_cid, :string
      add :depth, :int, null: false
    end
    create table(:tree_entries) do
      add :tree_entry_key, :text, primary_key: true, null: false # This is equivalent to record path
      add :parent_node_cid, :string, null: false
      add :value, :string, null: false # CID link to the record data (CBOR) for this entry
      add :right, :string # link to a sub-tree Node at a lower level which has keys sorting after this TreeEntry's key (to the "right"), but before the next TreeEntry's key in this Node (if any)
    end
  end

  migration SomeUsefulIndices do
    # Admittedly I might also be getting this wrong
    create index(:tree_entries, :parent_node_cid)
    create index(:mst_nodes, :parent_node_cid)
    create unique_index(:records, :record_cid)
    create index(:records, :collection)
    create unique_index(:tree_entries, :value)
    create index(:mst_nodes, :depth)
  end

  def all, do: Enum.reverse(@migrations)
end
