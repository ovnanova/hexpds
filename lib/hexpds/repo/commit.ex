defmodule Hexpds.Repo.Commit do
  alias Hexpds.DagCBOR
  import Hexpds.Helpers
  defstruct [:unsigned_commit, :sig]

  defmodule UnsignedCommit do
    defstruct [:did, :data, :rev, prev: nil, version: 3]

    import Hexpds.Helpers

    @type t :: %__MODULE__{
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

    def! to_dagcbor(commit)

    def sign_with_privkey(%UnsignedCommit{} = commit, privkey) do
      Hexpds.K256.PrivateKey.sign(privkey, to_dagcbor!(commit))
    end

    def sign_with_user_privkey(%UnsignedCommit{did: did} = commit) do
      sign_with_privkey(commit, Hexpds.User.get(did).signing_key)
    end

    def to_signed(commit, privkey \\ nil) do
      %Hexpds.Repo.Commit{
        unsigned_commit: commit,
        sig: case privkey do
          nil -> sign_with_user_privkey(commit)
          %Hexpds.K256.PrivateKey{} -> sign_with_privkey(commit, privkey)
        end
      }
    end

  end

  @type t :: %__MODULE__{
    unsigned_commit: UnsignedCommit.t(),
    sig: Hexpds.K256.Signature.t()
  }

  def to_dagcbor(%__MODULE__{unsigned_commit: raw_commit = %{rev: rev}, sig: %Hexpds.K256.Signature{sig: sig_bytes}}) do
    %{Map.delete(raw_commit, :__struct__) | rev: to_string(rev)}
    |> Map.put(:sig, DagCBOR.bytes(sig_bytes))
    |> DagCBOR.encode()
  end

  def! to_dagcbor(comm)

end

defmodule Hexpds.Repo.CommitBlock do

  # These come from Hexpds.User.Sqlite!!! Not from Hexpds.Database!!! (This whole naming thing will probably need to be moved around later)

  use Ecto.Schema

  schema "commits" do
    field :seq, :integer
    field :cid, :string

    timestamps()
  end
end
