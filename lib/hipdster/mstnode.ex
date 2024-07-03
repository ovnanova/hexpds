defmodule Hipdster.MST.MSTNode do
  @moduledoc """
  Represents a node in the merkle tree structure. It can function as both a
  leaf (is_terminal_node) and an internal node.

  - 'keys' - collection of rkeys
  - 'vals' - CID references to data
  - 'subtrees' - optional CID references to child nodes
  """
  @type t :: %__MODULE__{
          keys: [String.t()],
          vals: [Hipdster.CID.t()],
          subtrees: [Hipdster.CID.t() | nil]
        }

  defstruct keys: [], vals: [], subtrees: []
end
