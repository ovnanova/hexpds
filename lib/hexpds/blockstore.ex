defmodule Hexpds.BlockStore do
  @callback put_block(key :: binary(), value :: binary()) :: :ok | {:error, term()}
  @callback get_block(key :: binary()) :: {:ok, binary()} | {:error, term()}
  @callback del_block(key :: binary()) :: :ok | {:error, term()}
end

defmodule Hexpds.BlockStoreServer do
  use GenServer
  @behaviour Hexpds.BlockStore

  def init(init_arg) do
    {:ok, init_arg}
  end

  def start_link(inital_state \\ %{}) do
    GenServer.start_link(__MODULE__, inital_state, name: __MODULE__)
  end

  def put_block(key, value) do
    GenServer.call(__MODULE__, {:put_block, key, value})
  end

  def get_block(key) do
    GenServer.call(__MODULE__, {:get_block, key})
  end

  def del_block(key) do
    GenServer.cast(__MODULE__, {:del_block, key})
  end

  def init() do
    {:ok, :state}
  end

  def handle_call({:put_block, key, value}, _from, state) do
    case Map.fetch(state, key) do
      {:ok, ^value} -> {:reply, :ok, state}
      {:ok, _} -> {:reply, {:error, :immutable_value}, state}
      :error -> {:reply, :ok, Map.put(state, key, value)}
    end
  end

  def handle_call({:get_block, key}, _from, state) do
    case Map.fetch(state, key) do
      {:ok, value} -> {:reply, {:ok, value}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_cast({:del_block, key}, state) do
    {:noreply, Map.delete(state, key)}
  end
end

defmodule BlockStore.Repo do
  use Ecto.Repo,
    otp_app: :blockstore_app,
    adapter: Ecto.Adapters.SQLite3
end

defmodule BlocksTable do
  use Ecto.Schema

  schema "blocks" do
    field(:key, :string)
    field(:value, :string)
  end
end

defmodule Hexpds.EctoBlockStore do
  use Ecto.Repo, otp_app: :hexpds, adapter: Ecto.Adapters.SQLite3
  import Ecto.Query
  @behaviour Hexpds.BlockStore

  def init(_type, config) do
    {:ok, Keyword.put(config, :database, :memory)}
  end

  def put_block(key, value) do
    case get_by(BlocksTable, key: key) do
      nil ->
        case insert!(%BlocksTable{key: key, value: value}) do
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
    case get_by(BlocksTable, key: key) do
      nil -> {:error, :not_found}
      block -> {:ok, block.value}
    end
  end

  def del_block(key) do
    delete_all(from(b in BlocksTable, where: b.key == ^key))
  end
end

defmodule Hexpds.OverlayBlockStore do
  @behaviour Hexpds.BlockStore

  defstruct upper: nil, lower: nil

  def put_block(%{upper: upper}, key, value) do
    Hexpds.BlockStore.put_block(upper, key, value)
  end

  def get_block(%{upper: upper, lower: lower}, key) do
    case BlockStore.get_block(upper, key) do
      {:error, :not_found} -> BlockStore.get_block(lower, key)
      result -> result
    end
  end

  def del_block(%{upper: upper}, key) do
    BlockStore.del_block(upper, key)
  end
end
