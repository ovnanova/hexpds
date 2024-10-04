defmodule Hexpds.MST.Leaf do
  @moduledoc """
  Represents a leaf node in the MST
  """

  alias Hexpds.MST.Node
  alias Hexpds.CID

  @type t :: %Node{
          type: :leaf,
          key: String.t(),
          value: CID.t(),
          pointer: nil
        }

  @doc """
  Creates a new leaf node.

  ## Parameters

    - `key`: The key for the leaf.
    - `value`: The CID of the value.

  ## Examples

      iex> Hexpds.MST.Leaf.new("key1", %CID{})
      %Hexpds.MST.Node{type: :leaf, key: "key1", value: %CID{}, pointer: nil}
  """
  @spec new(String.t(), CID.t()) :: t()
  def new(key, %CID{} = value) when is_binary(key) do
    %Node{
      type: :leaf,
      key: key,
      value: value,
      pointer: nil
    }
  end
end
