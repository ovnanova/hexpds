defmodule Hexpds.MST.Leaf do
  @moduledoc """
  Represents a leaf node in the MST
  """

  alias Hexpds.CID

  defstruct [:key, :value]

  @type t :: %__MODULE__{
          key: String.t(),
          value: CID.t()
        }

  @doc """
  Checks if the given entry is a leaf
  """
  @spec is_leaf(t()) :: true
  def is_leaf(_leaf), do: true

  @doc """
  Checks if the given entry is a tree
  """
  @spec is_tree(t()) :: false
  def is_tree(_leaf), do: false

  @doc """
  Compares two leaf nodes for equality
  """
  @spec equals(t(), t()) :: boolean()
  def equals(%__MODULE__{key: key1, value: value1}, %__MODULE__{key: key2, value: value2}) do
    key1 == key2 and value1.multihash == value2.multihash
  end

  def equals(_, _), do: false
end
