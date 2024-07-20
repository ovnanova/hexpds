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

  def all, do: Enum.reverse(@migrations)
end
