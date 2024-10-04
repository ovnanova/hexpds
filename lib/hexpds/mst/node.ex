defmodule Hexpds.MST.Node do
  @moduledoc """
  Type  definitions for both internal MST nodes and leaf nodes
  """

  alias Hexpds.CID

  defstruct type: :internal,  # `:internal` or `:leaf`
            key: nil,         # Only for leaf nodes
            value: nil,       # CID only for leaf nodes
            pointer: nil      # CID for internal nodes

  @type t :: %__MODULE__{
          type: :internal | :leaf,
          key: String.t() | nil,
          value: CID.t() | nil,
          pointer: CID.t() | nil
        }
end
