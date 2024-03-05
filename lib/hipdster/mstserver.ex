defmodule Hipdster.MSTServer do
  use GenServer
  alias Hipdster.MST.MSTNode, as: MSTNode

  # Starting the server with an empty root
  def start_link(args \\ %MSTNode{subtrees: [nil], keys: [], vals: []}) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  # GenServer callback for initialization
  def init(state) do
    {:ok, state}
  end

  # Other callbacks, get, put, etc.
  def handle_call({:get, key}, _from, state) do
    # To-do
    # Pattern match on the state
    # Recursively search the tree for the key
    # {:reply, value, state}
  end

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
end
