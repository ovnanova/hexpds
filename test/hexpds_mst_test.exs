defmodule Hexpds.MSTTest do
  use ExUnit.Case, async: false

  alias Hexpds.MST
  alias Hexpds.CID

  setup do
    {:ok, storage_pid} = Hexpds.MST.Storage.start_link([])
    {:ok, storage: storage_pid}
  end

  test "inserting entries triggers subtree splitting", %{storage: storage} do
    {:ok, mst} = MST.create(storage, [])

    # Insert @max_entries + 1 entries to trigger a split
    max = MST.max_entries()
    entries = for i <- 1..(max + 1), do: {"key#{i}", CID.cid!("value#{i}", "dag-cbor", 1)}

    # Insert entries one by one
    final_mst =
      Enum.reduce(entries, {:ok, mst}, fn {key, cid}, {:ok, acc_mst} ->
        MST.add(acc_mst, key, cid)
      end)
      |> elem(1)

    # Verify that the root node now has two subtrees
    {:ok, root_entries} = MST.get_entries(final_mst)
    assert length(root_entries) == 2

    # Verify that each subtree has at most @max_entries
    Enum.each(root_entries, fn subtree ->
      {:ok, entries} = MST.get_entries(subtree)
      assert length(entries) <= MST.max_entries()
    end)
  end

  test "retrieving all inserted entries after splitting", %{storage: storage} do
    {:ok, mst} = MST.create(storage, [])

    # Insert multiple entries
    entries = for i <- 1..100, do: {"key#{i}", CID.cid!("value#{i}", "dag-cbor", 1)}

    # Insert entries one by one
    final_mst =
      Enum.reduce(entries, {:ok, mst}, fn {key, cid}, {:ok, acc_mst} ->
        MST.add(acc_mst, key, cid)
      end)
      |> elem(1)

    # Retrieve each entry and verify
    Enum.each(entries, fn {key, cid} ->
      {:ok, retrieved_cid} = MST.get(final_mst, key)
      assert retrieved_cid == cid
    end)
  end

  test "serialization and deserialization maintain tree integrity", %{storage: storage} do
    {:ok, mst} = MST.create(storage, [])

    # Insert multiple entries
    entries = for i <- 1..50, do: {"key#{i}", CID.cid!("value#{i}", "dag-cbor", 1)}

    # Insert entries
    final_mst =
      Enum.reduce(entries, {:ok, mst}, fn {key, cid}, {:ok, acc_mst} ->
        MST.add(acc_mst, key, cid)
      end)
      |> elem(1)

    # Serialize the tree
    {:ok, serialized} = MST.Util.serialize_node_data(final_mst.entries, storage)

    # Deserialize into a new MST
    {:ok, deserialized_entries} = MST.Util.deserialize_node_data(serialized, storage)
    {:ok, deserialized_mst} = MST.new_tree(final_mst, deserialized_entries)

    # Verify that all entries are present
    Enum.each(entries, fn {key, cid} ->
      {:ok, retrieved_cid} = MST.get(deserialized_mst, key)
      assert retrieved_cid == cid
    end)
  end
end
