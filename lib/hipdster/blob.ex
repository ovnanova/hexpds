defmodule Hipdster.Blob do
  @moduledoc """
  An ATProto blob. Has a CID, mime-type, raw data, DID of the owner.
  A list of references will likely be added once we have repos working.
  """
  alias Hipdster.CID

  use Ecto.Schema
  import Ecto.Query

  schema "blobs" do
    # hash of did + cid (sha256) to avoid duplicates
    field(:hash, :binary)
    field(:did, :string)
    field(:cid, Ecto.Types.Cid)
    field(:mime_type, :string)
    field(:data, :binary)
    timestamps()
  end

  @type t :: %__MODULE__{
          cid: Hipdster.CID.t(),
          mime_type: String.t(),
          data: binary(),
          did: Hipdster.Identity.did(),
          hash: <<_::256>>
        }

  def new(raw_bytes, %Hipdster.User{did: did}) do
    %__MODULE__{
      cid:
        raw_bytes
        |> bytes_to_cid(),
      mime_type: get_mime_type(raw_bytes),
      data: raw_bytes,
      did: did,
      hash: hash(did, raw_bytes)
    }
  end

  @spec bytes_to_cid(binary()) :: Hipdster.CID.t()
  def bytes_to_cid(bytes) do
    with {:ok, multihash} <- Multihash.encode(:sha2_256, :crypto.hash(:sha256, bytes)) do
      multihash |> CID.cid!("raw")
    end
  end

  def hash(did, "bafkr" <> _ = cid)  do
    hash(did, CID.decode_cid!(cid))
  end
  def hash(did, %CID{} = cid), do: :crypto.hash(:sha256, did <> cid_string(cid))
  def hash(did, bytes) do
    hash(did, bytes |> bytes_to_cid())
  end


  defp get_mime_type(<<>> <> data) do
    Infer.get(data) |> get_mime_type()
  end

  defp get_mime_type(%{mime_type: mime_type}), do: mime_type
  defp get_mime_type(nil), do: "application/octet-stream"

  @spec cid_string(Hipdster.Blob.t() | Hipdster.CID.t() | String.t()) :: binary()
  def cid_string(%__MODULE__{cid: cid}), do: cid_string(cid)

  def cid_string(%CID{} = cid), do: Hipdster.CID.encode!(cid, :base32_lower)
  def cid_string("bafkr" <> _ = cid), do: cid

  def save(%__MODULE__{} = blob), do: Hipdster.Database.insert(blob)

  def get(cid, "did:" <> _ = did) do
    hash = hash(did, cid_string(cid))
    (from Hipdster.Blob, where: [hash: ^hash])
    |> Hipdster.Database.one()
  end

  def get("did:" <> _ = did, cid), do: get(cid, did)

  def with_did(cid) do
    (from Hipdster.Blob, where: [cid: ^cid])
    |> Hipdster.Database.all()
  end
  def of_user(%Hipdster.User{did: did}) do
    (from Hipdster.Blob, where: [did: ^did])
    |> Hipdster.Database.all()
  end
end
