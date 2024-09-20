defmodule Hexpds.MST do
  @moduledoc """
  Merkle Search Tree (MST) implementation
  """

  alias Hexpds.CID
  alias Hexpds.DagCBOR.Internal
  alias Hexpds.MST.Storage
  alias Hexpds.MST.Util
  alias Hexpds.MST.Leaf

  @max_entries 32  # Tune this

  # Expose @max_entries for testing
  @doc """
  Returns the maximum number of entries allowed per MST node
  """
  @spec max_entries() :: non_neg_integer()
  def max_entries, do: @max_entries

  @type node_entry :: Hexpds.MST.t() | Hexpds.MST.Leaf.t()

  defstruct storage: nil,
            entries: nil,
            layer: nil,
            pointer: nil,
            outdated_pointer: false

  @type t :: %__MODULE__{
          storage: pid(),
          entries: [node_entry()] | nil,
          layer: non_neg_integer() | nil,
          pointer: CID.t() | nil,
          outdated_pointer: boolean()
        }

  @doc """
  Creates a new MST

  ## Parameters

    - `storage`: The storage module PID to use
    - `entries`: Initial list of node entries
    - `opts`: Options such as `layer`

  ## Examples

      iex> {:ok, mst} = Hexpds.MST.create(storage_pid, [])
  """
  @spec create(pid(), [node_entry()], keyword()) :: {:ok, t()} | {:error, term()}
  def create(storage, entries \\ [], opts \\ []) do
    layer = Keyword.get(opts, :layer, nil)

    with {:ok, pointer} <- Util.cid_for_entries(entries, storage) do
      {:ok,
       %__MODULE__{
         storage: storage,
         entries: entries,
         layer: layer,
         pointer: pointer,
         outdated_pointer: false
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Loads an existing MST from storage using its CID

  This function performs a lazy load; it doesn't fetch the entries immediately

  ## Parameters

    - `storage`: The storage module PID to use
    - `cid`: The CID of the MST node
    - `opts`: Options such as `layer`

  ## Examples

      iex> mst = Hexpds.MST.load(storage_pid, cid)
  """
  @spec load(pid(), CID.t(), keyword()) :: t()
  def load(storage, cid, opts \\ []) do
    layer = Keyword.get(opts, :layer, nil)

    %__MODULE__{
      storage: storage,
      pointer: cid,
      layer: layer,
      entries: nil,
      outdated_pointer: false
    }
  end

  @doc """
  Retrieves the entries of the MST

  If entries are not loaded, it fetches them from storage

  ## Parameters

    - `mst`: The MST instance

  ## Examples

      iex> {:ok, entries} = Hexpds.MST.get_entries(mst)
  """
  @spec get_entries(t()) :: {:ok, [node_entry()]} | {:error, term()}
  def get_entries(%__MODULE__{entries: entries} = _mst) when not is_nil(entries) do
    {:ok, entries}
  end

  def get_entries(%__MODULE__{pointer: %CID{} = cid, storage: storage} = mst) do
    with {:ok, data} <- Storage.read_obj(cid),
         {:ok, entries} <- Util.deserialize_node_data(data, storage, mst) do
      {:ok, entries}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "No entries or CID provided"}
    end
  end

  @doc """
  Updates the entries of the MST

  Marks the pointer as outdated

  ## Parameters

    - `mst`: The MST instance
    - `entries`: New list of node entries

  ## Examples

      iex> {:ok, updated_mst} = Hexpds.MST.new_tree(mst, new_entries)
  """
  @spec new_tree(t(), [node_entry()]) :: {:ok, t()} | {:error, term()}
  def new_tree(mst, entries) do
    {:ok, %__MODULE__{mst | entries: entries, outdated_pointer: true}}
  end

  @doc """
  Retrieves the CID pointer of the MST

  If the pointer is outdated, it serializes the MST and updates the pointer

  ## Parameters

    - `mst`: The MST instance

  ## Examples

      iex> {:ok, cid} = Hexpds.MST.get_pointer(mst)
  """
  @spec get_pointer(t()) :: {:ok, CID.t()} | {:error, term()}
  def get_pointer(%__MODULE__{outdated_pointer: false, pointer: cid}) do
    {:ok, cid}
  end

  def get_pointer(%__MODULE__{entries: entries, storage: storage} = mst) do
    with {:ok, serialized_entries} <- Util.serialize_node_data(entries, storage),
         {:ok, new_cid} <- CID.cid(serialized_entries, "dag-cbor", 1),
         :ok <- Storage.put_block(storage, new_cid, serialized_entries) do
      {:ok, new_cid}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to get pointer"}
    end
  end

  @doc """
  Adds a new leaf to the MST

  ## Parameters

    - `mst`: The MST instance
    - `key`: The key for the new leaf
    - `value`: The CID of the value

  ## Examples

      iex> {:ok, new_mst} = Hexpds.MST.add(mst, "key1", value_cid)
  """
  @spec add(t(), String.t(), CID.t()) :: {:ok, t()} | {:error, term()}
  def add(%__MODULE__{} = mst, key, %CID{} = value) do
    with :ok <- Util.ensure_valid_mst_key(key),
         {:ok, key_zeros} <- Util.leading_zeros_on_hash(key),
         {:ok, layer} <- get_layer(mst),
         {:ok, new_leaf} <- create_leaf(key, value),
         {:ok, updated_mst} <- insert_entry(mst, new_leaf, key_zeros, layer) do
      {:ok, updated_mst}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to add key: #{key}"}
    end
  end

  @doc """
  Retrieves the value CID associated with the given key

  ## Parameters

    - `mst`: The MST instance
    - `key`: The key to retrieve

  ## Examples

      iex> {:ok, value_cid} = Hexpds.MST.get(mst, "key1")
  """
  @spec get(t(), String.t()) :: {:ok, CID.t()} | {:error, term()}
  def get(%__MODULE__{} = mst, key) do
    with {:ok, entries} <- get_entries(mst),
         {:ok, index} <- find_gt_or_equal_leaf_index(mst, key),
         {:ok, found} <- at_index(mst, index),
         {:ok, value} <- extract_value(found, key) do
      {:ok, value}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Key not found: #{key}"}
    end
  end

  @doc """
  Updates the value CID for the given key

  ## Parameters

    - `mst`: The MST instance
    - `key`: The key to update
    - `value`: The new CID of the value

  ## Examples

      iex> {:ok, updated_mst} = Hexpds.MST.update(mst, "key1", new_value_cid)
  """
  @spec update(t(), String.t(), CID.t()) :: {:ok, t()} | {:error, term()}
  def update(%__MODULE__{} = mst, key, %CID{} = value) do
    with :ok <- Util.ensure_valid_mst_key(key),
         {:ok, index} <- find_gt_or_equal_leaf_index(mst, key),
         {:ok, found} <- at_index(mst, index),
         {:ok, updated_mst} <- update_entry(mst, found, key, value) do
      {:ok, updated_mst}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to update key: #{key}"}
    end
  end

  @doc """
  Deletes the leaf with the given key from the MST

  ## Parameters

    - `mst`: The MST instance
    - `key`: The key to delete

  ## Examples

      iex> {:ok, updated_mst} = Hexpds.MST.delete(mst, "key1")
  """
  @spec delete(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def delete(%__MODULE__{} = mst, key) do
    with {:ok, updated_mst} <- delete_recurse(mst, key),
         {:ok, trimmed_mst} <- trim_top(updated_mst) do
      {:ok, trimmed_mst}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to delete key: #{key}"}
    end
  end

  @doc """
  Lists leaves in the MST with optional pagination

  ## Parameters

    - `mst`: The MST instance
    - `count`: Maximum number of leaves to return
    - `after_key`: Start listing after this key
    - `before`: Stop listing before this key

  ## Examples

      iex> {:ok, leaves} = Hexpds.MST.list(mst, 10, "key1", "key10")
  """
  @spec list(t(), non_neg_integer(), String.t() | nil, String.t() | nil) ::
          {:ok, [Hexpds.MST.Leaf.t()]} | {:error, term()}
  def list(%__MODULE__{} = mst, count \\ :infinity, after_key \\ nil, before \\ nil) do
    with {:ok, leaves} <- walk_leaves_from(mst, after_key) do
      filtered =
        leaves
        |> Enum.reject(fn leaf ->
          if after_key, do: leaf.key == after_key, else: false
        end)
        |> Enum.take(count)
        |> Enum.take_while(fn leaf ->
          if before, do: leaf.key < before, else: true
        end)

      {:ok, filtered}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to list leaves"}
    end
  end

  @doc """
  Encodes the MST into a CAR  stream

  ## Parameters

    - `mst`: The MST instance
    - `car`: The CAR writer

  ## Examples

      iex> {:ok, :written} = Hexpds.MST.write_to_car_stream(mst, car_writer)
  """
  @spec write_to_car_stream(t(), Hexpds.Car.Writer.t()) :: {:ok, :written} | {:error, term()}
  def write_to_car_stream(%__MODULE__{} = mst, car) do
    with {:ok, root_cid} <- get_pointer(mst),
         :ok <- write_node(mst, car) do
      {:ok, :written}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to write to CAR stream"}
    end
  end

  @doc """
  Retrieves all CIDs in the MST
  """
  @spec all_cids(t()) :: {:ok, MapSet.t()} | {:error, term()}
  def all_cids(%__MODULE__{} = mst) do
    with {:ok, cids} <- traverse(mst, MapSet.new()) do
      {:ok, cids}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to retrieve all CIDs"}
    end
  end

  # Private Helper Functions

  defp create_leaf(key, %CID{} = value) do
    {:ok, %Leaf{key: key, value: value}}
  end

  defp insert_entry(%__MODULE__{entries: entries, layer: layer} = mst, %Leaf{} = new_leaf, key_zeros, layer) do
    # Find the index to insert the new leaf to keep entries sorted
    index = find_gt_or_equal_leaf_index(mst, new_leaf.key)

    case Enum.at(entries, index) do
      %Leaf{key: existing_key} when existing_key == new_leaf.key ->
        {:error, "There is already a value at key: #{new_leaf.key}"}

      %Leaf{} ->
        updated_entries = List.insert_at(entries, index, new_leaf)

        if length(updated_entries) > @max_entries do
          # Node exceeds max entries, perform splitting
          case split_node(%__MODULE__{mst | entries: updated_entries, outdated_pointer: true}) do
            {:ok, left_subtree, right_subtree} ->
              # Replace current entries with the two new subtrees
              new_entries = [left_subtree, right_subtree]
              new_tree(mst, new_entries)

            {:error, reason} ->
              {:error, "Failed to split node: #{reason}"}
          end
        else
          # No need to split, simply update the tree
          new_tree(mst, updated_entries)
        end

      %__MODULE__{} ->
        # Handle subtree insertion if necessary
        {:error, "Subtree insertion not implemented yet"}

      _ ->
        {:error, "Unknown entry type during insertion"}
    end
  end

  defp insert_entry(_mst, _entry, _key_zeros, _layer) do
    {:error, "Incompatible layer for insertion"}
  end

  defp get_layer(%__MODULE__{layer: layer}) when not is_nil(layer), do: {:ok, layer}

  defp get_layer(mst) do
    Util.layer_for_entries(mst.entries || [])
  end

  defp at_index(mst, index) do
    with {:ok, entries} <- get_entries(mst),
         entry <- Enum.at(entries, index) do
      {:ok, entry}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Index out of bounds"}
    end
  end

  defp extract_value(%Leaf{key: key, value: value}, search_key) when key == search_key do
    {:ok, value}
  end

  defp extract_value(%__MODULE__{entries: entries}, _search_key) when is_list(entries) do
    {:error, "Not a leaf node"}
  end

  defp extract_value(_, _), do: {:error, "Invalid entry type"}

  defp update_entry(mst, %Leaf{key: key}, key, %CID{} = new_value) do
    new_leaf = %Leaf{key: key, value: new_value}
    {:ok, updated_entries} = replace_entry(mst, key, new_leaf)
    {:ok, new_tree(mst, updated_entries)}
  end

  defp update_entry(_mst, _found, _key, _value), do: {:error, "Key not found for update"}

  defp replace_entry(%__MODULE__{entries: entries} = mst, key, new_leaf) do
    updated_entries =
      Enum.map(entries, fn
        %Leaf{key: ^key} -> new_leaf
        other -> other
      end)

    {:ok, updated_entries}
  end

  defp delete_recurse(mst, key) do
    with {:ok, entries} <- get_entries(mst),
         {:ok, index} <- find_gt_or_equal_leaf_index(mst, key),
         {:ok, found} <- at_index(mst, index),
         {:ok, updated_entries} <- remove_entry(mst, found, key) do
      {:ok, %__MODULE__{mst | entries: updated_entries, outdated_pointer: true}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Key not found for deletion"}
    end
  end

  defp remove_entry(%__MODULE__{entries: entries} = mst, %Leaf{key: key}, key) do
    updated_entries = Enum.reject(entries, fn
      %Leaf{key: ^key} -> true
      _ -> false
    end)

    {:ok, updated_entries}
  end

  defp remove_entry(_mst, _found, _key), do: {:error, "Entry to remove not found"}

  defp trim_top(mst) do
    with {:ok, entries} <- get_entries(mst),
         true <- length(entries) == 1,
         [only_entry] <- entries,
         %__MODULE__{} = subtree <- only_entry do
      {:ok, subtree}
    else
      {:ok, entries} when is_list(entries) and length(entries) > 1 ->
        {:ok, mst}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Failed to trim top"}
    end
  end

  defp walk_leaves_from(mst, after_key) do
    with {:ok, entries} <- get_entries(mst) do
      leaves = traverse_entries(entries, [], after_key)
      {:ok, leaves}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to walk leaves from key: #{after_key}"}
    end
  end

  defp traverse_entries([], acc, _after_key), do: Enum.reverse(acc)

  defp traverse_entries([%Leaf{} = leaf | rest], acc, after_key) do
    if after_key == nil or leaf.key > after_key do
      traverse_entries(rest, [leaf | acc], after_key)
    else
      traverse_entries(rest, acc, after_key)
    end
  end

  defp traverse_entries([%__MODULE__{} = subtree | rest], acc, after_key) do
    with {:ok, entries} <- get_entries(subtree),
         {:ok, new_acc} <- traverse_entries(entries, acc, after_key) do
      traverse_entries(rest, new_acc, after_key)
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to traverse subtree"}
    end
  end

  defp traverse_entries([_ | rest], acc, after_key) do
    traverse_entries(rest, acc, after_key)
  end

  defp traverse(%__MODULE__{} = mst, acc) do
    with {:ok, entries} <- get_entries(mst),
         {:ok, new_acc} <- traverse_entries(entries, acc, nil) do
      {:ok, new_acc}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to traverse subtree"}
    end
  end

  defp write_node(mst, car) do
    with {:ok, serialized_entries} <- Util.serialize_node_data(mst.entries, mst.storage),
         {:ok, cid} <- CID.cid(serialized_entries, "dag-cbor", 1),
         :ok <- Hexpds.Car.Writer.put(car, cid, serialized_entries) do
      {:ok, :written}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to write node to CAR stream"}
    end
  end

  defp find_gt_or_equal_leaf_index(mst, key) do
    with {:ok, entries} <- get_entries(mst) do
      index =
        Enum.find_index(entries, fn
          %Leaf{key: leaf_key} -> leaf_key >= key
          _ -> false
        end)

      {:ok, if(index != nil, do: index, else: length(entries))}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to find index for key: #{key}"}
    end
  end

  # Splitting logic as defined earlier
  defp split_node(%__MODULE__{entries: entries, storage: storage} = mst) do
    # Ensure entries are sorted by key
    sorted_entries = Enum.sort_by(entries, &get_entry_key/1)

    # Find the split index (median)
    split_index = div(length(sorted_entries), 2)

    # Divide entries into two halves
    {left_entries, right_entries} = Enum.split(sorted_entries, split_index)

    # Create left and right subtrees
    with {:ok, left_subtree} <- create_subtree(left_entries, storage),
         {:ok, right_subtree} <- create_subtree(right_entries, storage) do
      {:ok, left_subtree, right_subtree}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to create subtrees during split"}
    end
  end

  defp get_entry_key(%Leaf{key: key}), do: key
  defp get_entry_key(%__MODULE__{pointer: %CID{} = _cid}), do: ""

  defp create_subtree(entries, storage) do
    # Create a new MST node with the given entries
    with {:ok, subtree} <- new_tree(storage, entries),
         {:ok, subtree_cid} <- get_pointer(subtree),
         {:ok, serialized_entries} <- Util.serialize_node_data(entries, storage),
         :ok <- Storage.put_block(storage, subtree_cid, serialized_entries) do
      {:ok, subtree}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to create subtree"}
    end
  end
end
