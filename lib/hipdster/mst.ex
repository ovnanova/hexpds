defmodule Hipdster.MST do
  alias Hipdster.MST
  alias Hipdster.MST.MSTNode, as: MSTNode
  @hash_fun :sha256

  def terminal_node?(%MSTNode{subtrees: subtrees}) do
    Enum.empty?(subtrees)
  end

  def build_tree(data_list) when is_list(data_list) do
    leaves = Enum.map(data_list, &create_node(&1))
    build_nodes(leaves, nil)
  end

  defp create_node(data) do
    # hash = :crypto.hash(@hash_fun, data)
    # %MSTNode{hash: hash, subtrees: []}
  end

  defp build_nodes([single_node], _parent) do
    single_node
  end

  # defp build_nodes(nodes, _parent) do
  #   paired_nodes = Enum.chunk_every(nodes, 2, 2, :undefined)

  #   parent_nodes =
  #     Enum.map(paired_nodes, fn [left = %MSTNode{hash: left_hash}, right] ->
  #       right_hash =
  #         case right do
  #           # %MSTNode{hash: hash} -> hash
  #           :undefined -> ""
  #           _ -> :crypto.hash(@hash_fun, "")
  #         end
  #     end)

  #   build_nodes(parent_nodes, nil)
  # end

  defp build_nodes([single_hash], _parent) do
    # This is a single node tree (or a root for its subtree), no parent is needed.
    single_hash
  end

  defp build_nodes(hashes, parent) do
    paired_hashes = Enum.chunk_every(hashes, 2, 2, :undefined)

    parent_hashes =
      Enum.map(paired_hashes, fn [left, right] ->
        {left_hash, right_hash} = {left || :undefined, right || :undefined}
        combined = if right_hash == :undefined, do: left_hash, else: left_hash <> right_hash
        hash = :crypto.hash(@hash_fun, combined)
        # Insert each parent node into the ETS table. Each parent node contains
        # its hash, the hashes of its left and right children, and its own parent.
        :ets.insert(:merkle_tree, {hash, left_hash, right_hash, parent})
        hash
      end)

    build_nodes(parent_hashes, nil)
  end

  # defp leaf_hash(leaf) when is_nil(leaf), do: ""
  # defp leaf_hash(%Hipdster.MST.MSTNode{hash: hash}), do: hash

  def verify(tree_hash, data) do
    # Hmmm
  end

  def depth(key), do: hash_depth(:crypto.hash(:sha256, key))
  def hash_depth(key, depth \\ 0)

  def hash_depth(<<0::2, rest::bitstring>>, depth), do: hash_depth(rest, depth + 1)

  def hash_depth(<<_::2, _rest::bitstring>>, depth), do: depth
end

defmodule Hipdster.MSTServer do
  use GenServer
  alias Hipdster.MST.MSTNode, as: MSTNode

  # Starting the server with an empty root
  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(%MSTNode{subtrees: [nil], keys: [], vals: []} = args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # GenServer callback for initialization
  def init(_) do
    # Initialize the ETS table with the name :merkle_tree, making it a set
    # where each object is unique and public so all processes can access it.
    # The :keypos option indicates the position of the key in the tuple (2nd position here).
    table = :ets.new(:merkle_tree, [:set, :public, {:keypos, 2}])
    {:ok, table}
  end

  # Other callbacks, get, put, etc.
  def handle_call({:get, key}, _from, state) do
    # To-do
    # Pattern match on the state
    # Recursively search the tree for the key
    # {:reply, value, state}
  end

  def handle_call({:add_data, data}, from, state), do: {:reply, add_data(data, state)}

  def handle_cast({:put, key, value}, state) do
    # To-do
    # Insert the key-value pair into the tree
    # Recursively adjust the tree structure
    # {:noreply, new_state}
  end

  def handle_cast({:delete, key}, state) do
    # Implement logic to remove a key-value pair from the tree
    # Adjust the tree structure accordingly
    # {:noreply, new_state}
  end

  def add_data(data, table) do
    hash = :crypto.hash(@hash_fun, data)
    # Insert a tuple into the ETS table with the structure {hash, data}.
    :ets.insert(table, {hash, data})
    hash
  end

  # def build_tree(data_list) when is_list(data_list) do
  #   hashed_data = Enum.map(data_list, &add_data())
  #   build_nodes(hashed_data, nil)
  # end
end
