defmodule Hexpds.MST.Storage do
  @moduledoc """
  Storage module for the MST
  """

  use Agent

  alias Hexpds.CID

  @doc """
  Starts the storage agent
  """
  @spec start_link(any()) :: {:ok, pid()} | {:error, any()}
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Reads an object by its CID
  """
  @spec read_obj(CID.t()) :: {:ok, binary()} | {:error, :not_found}
  def read_obj(%CID{multihash: multihash} = _cid) do
    cid_binary = multihash

    Agent.get(__MODULE__, fn store ->
      case Map.get(store, cid_binary) do
        nil -> {:error, :not_found}
        data -> {:ok, data}
      end
    end)
  end

  @doc """
  Checks if a block exists for the given CID
  """
  @spec has?(CID.t()) :: boolean()
  def has?(%CID{multihash: multihash}) do
    cid_binary = multihash

    Agent.get(__MODULE__, fn store ->
      Map.has_key?(store, cid_binary)
    end)
  end

  @doc """
  Retrieves multiple blocks by their CIDs

  Returns a map with found blocks and a list of missing CIDs
  """
  @spec get_blocks([CID.t()]) :: %{blocks: %{binary() => binary()}, missing: [CID.t()]}
  def get_blocks(cids) do
    cid_binaries = Enum.map(cids, & &1.multihash)

    Agent.get(__MODULE__, fn store ->
      found = Enum.reduce(cid_binaries, %{}, fn cid, acc ->
        case Map.get(store, cid) do
          nil -> acc
          data -> Map.put(acc, cid, data)
        end
      end)

      missing = cid_binaries -- Map.keys(found)

      %{
        blocks: found,
        missing: Enum.map(missing, fn cid_bin ->
          # Need to double-check CID version
          %CID{version: 1, codec: "dag-cbor", multihash: cid_bin}
        end)
      }
    end)
  end

  @doc """
  Adds a block to storage
  """
  @spec put_block(pid(), CID.t(), binary()) :: {:ok, :stored} | {:error, term()}
  def put_block(storage_pid, %CID{multihash: multihash} = _cid, data) do
    cid_binary = multihash

    Agent.update(storage_pid, fn store ->
      Map.put(store, cid_binary, data)
    end)

    {:ok, :stored}
  end

  @doc """
  Adds multiple blocks to storage
  """
  @spec put_blocks(pid(), [{CID.t(), binary()}]) :: :ok
  def put_blocks(storage_pid, blocks) do
    Agent.update(storage_pid, fn store ->
      Enum.reduce(blocks, store, fn {cid, data}, acc ->
        Map.put(acc, cid.multihash, data)
      end)
    end)

    :ok
  end

  @doc """
  Initializes the storage with predefined blocks
  """
  @spec init_blocks(pid(), [{CID.t(), binary()}]) :: :ok
  def init_blocks(storage_pid, blocks) do
    Agent.update(storage_pid, fn _store ->
      Enum.into(blocks, %{}, fn {cid, data} -> {cid.multihash, data} end)
    end)

    :ok
  end
end
