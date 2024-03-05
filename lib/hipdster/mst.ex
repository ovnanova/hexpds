defmodule Hipdster.MST do
  @hash_fun :sha256

  defmodule MSTNode do
    defstruct subtrees: [], keys: [], vals: []
  end

  defmodule Leaf do
    defstruct key: nil, value: nil
  end

  def start_link do
    # Initialize the ETS table with the name :merkle_tree, making it a set
    # where each object is unique and public so all processes can access it.
    # The :keypos option indicates the position of the key in the tuple (2nd position here).
    :ets.new(:merkle_tree, [:set, :public, {:keypos, 2}])
    {:ok, %{}}
  end

  def add_data(data) do
    hash = :crypto.hash(@hash_fun, data)
    # Insert a tuple into the ETS table with the structure {hash, data}.
    :ets.insert(:merkle_tree, {hash, data})
    hash
  end

  def build_tree(data_list) when is_list(data_list) do
    hashed_data = Enum.map(data_list, &add_data/1)
    build_nodes(hashed_data, nil)
  end

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

  def verify(tree_hash, data) do
    # Hmmm
  end
end
