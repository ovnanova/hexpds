defmodule Hexpds.BlockStore do
  @callback put_block(key :: binary(), value :: binary()) :: :ok | {:error, term()}
  @callback get_block(key :: binary()) :: {:ok, binary()} | {:error, term()}
  @callback del_block(key :: binary()) :: :ok | {:error, term()}
end

defmodule Hexpds.BlocksTable do
  use Ecto.Schema

  schema "blocks" do
    field(:key, :string)
    field(:value, :binary)
  end
end

defmodule Hexpds.EctoBlockStore do
  import Ecto.Query
  alias Hexpds.BlocksTable
  @behaviour Hexpds.BlockStore

  def init(_type, config) do
    {:ok, Keyword.put(config, :database, :memory)}
  end

  def put_block(key, value) do
    case Hexpds.Database.get_by(BlocksTable, key: key) do
      nil ->
        case Hexpds.Database.insert!(%BlocksTable{key: key, value: value}) do
          {:ok, _} -> :ok
          {:error, _} -> {:error, :insert_failed}
        end

      {:ok, res} when res == value ->
        :ok

      {:ok, _} ->
        {:error, :different_value}

      {:error, _} ->
        {:error, :get_failed}
    end
  end

  def get_block(key) do
    case Hexpds.Database.get_by(BlocksTable, key: key) do
      nil -> {:error, :not_found}
      block -> {:ok, block.value}
    end
  end

  def del_block(key) do
    Hexpds.Database.delete_all(from(b in BlocksTable, where: b.key == ^key))
  end
end
