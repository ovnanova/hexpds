defmodule Hexpds.Repo.Commit do
  defmodule UnsignedCommit do
    defstruct [:did, :data, :rev, prev: nil, version: 3]

    @type t :: %UnsignedCommit{
      did: String.t(),
      data: Hexpds.CID.cid_string(),
      rev: Hexpds.Tid.t(),
      prev: Hexpds.CID.cid_string() | nil,
      version: 3
    }

    def to_dagcbor(%UnsignedCommit{rev: rev} = commit) do
      %{Map.delete(commit, :__struct__) | rev: to_string(rev)}
      |> Hexpds.DagCBOR.encode()
    end

  end

  defstruct [:unsigned_commit, :sig]

end
