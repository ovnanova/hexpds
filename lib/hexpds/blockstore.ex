defmodule Hexpds.BlockStore do
  @callback put_block(value :: binary()) :: :ok | {:error, term()}
  @callback get_block(key :: binary()) :: {:ok, binary()} | {:error, term()}
  @callback del_block(key :: binary()) :: :ok | {:error, term()}
end

defmodule Hexpds.BlocksTable do
  use Ecto.Schema

  schema "blocks" do
    field(:block_cid, :string) # A CID
    field(:block_value, :binary) # A Dag-CBOR blob

    timestamps()
  end
end

defmodule Hexpds.EctoBlockStore do
  import Ecto.Query
  alias Hexpds.{BlockStore, DagCBOR, BlocksTable}
  @behaviour BlockStore

  @impl BlockStore
  def put_block(value) do
    cid = Hexpds.Repo.Helpers.term_to_dagcbor_cid(value)
    case get_block(cid) do
      {:error, :not_found} ->
        %BlocksTable{
          block_cid: cid,
          block_value: DagCBOR.encode!(value)
        }
        |> Hexpds.User.Sqlite.insert!()
      anything_else -> anything_else
    end
  end

  @impl BlockStore
  def get_block(key) do
    case Hexpds.User.Sqlite.get_by(BlocksTable, block_cid: key) do
      nil -> {:error, :not_found}
      %BlocksTable{} = block -> block
    end
  end

  @impl BlockStore
  def del_block(key) do
    Hexpds.User.Sqlite.delete_all(from(b in BlocksTable, where: b.block_cid == ^key))
  end
end
