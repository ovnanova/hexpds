defmodule Hexpds.Blob do
  @moduledoc """
  An ATProto blob. Has a CID, mime-type, raw data, DID of the owner.
  A list of references will likely be added once we have repos working.
  """
  alias Hexpds.CID

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
          id: integer(),
          cid: Hexpds.CID.t(),
          mime_type: String.t(),
          data: binary(),
          did: Hexpds.Identity.did(),
          hash: <<_::256>>,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc """
  Creates a new blob from raw bytes and the DID of the owner.
  Calculates the CID, mime-type, and hash.
  """
  def new(raw_bytes, %Hexpds.User{did: did}) do
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

  @doc """
  CID reference to blob, with multicodec type `raw`,
  in accordance with ATProto data model.
  """
  @spec bytes_to_cid(binary()) :: Hexpds.CID.t()
  def bytes_to_cid(bytes) do
    with {:ok, multihash} <- Multihash.encode(:sha2_256, :crypto.hash(:sha256, bytes)) do
      multihash |> CID.cid!("raw")
    end
  end

  @doc """
  Given a DID and a CID, appends the DID to the CID as a string
  and takes the sha256 hash. This is used to ensure uniqueness
  of blobs in the database, even when two users upload the
  exact same blob. That way one user's blob is not overwritten
  by another user's. This is also used to lookup blobs fast,
  though SQL is fast enough that it doesn't really matter.

  (This is not part of the ATP spec, just a weird
  hack I added)
  """
  def hash(did, "bafkr" <> _ = cid) do
    hash(did, CID.decode_cid!(cid))
  end

  def hash(did, %CID{} = cid), do: :crypto.hash(:sha256, did <> cid_string(cid))

  def hash(did, bytes) do
    hash(did, bytes |> bytes_to_cid())
  end

  @spec get_mime_type(binary()) :: String.t()
  @spec get_mime_type(nil) :: String.t()
  @spec get_mime_type(Infer.Type.t()) :: String.t()
  @doc """
  Given the bytes of the blob being uploaded, returns the mime-type.
  If the mime-type cannot be determined, returns "application/octet-stream".
  """
  def get_mime_type(<<>> <> data) do
    Infer.get(data)
    |> get_mime_type()
  end

  def get_mime_type(%Infer.Type{mime_type: mime_type}), do: mime_type
  def get_mime_type(nil), do: "application/octet-stream"

  @spec cid_string(Hexpds.Blob.t() | Hexpds.CID.t() | String.t()) :: binary()
  @doc """
  Given a blob or CID, returns the string representation of the CID.
  """
  def cid_string(%__MODULE__{cid: cid}), do: cid_string(cid)
  def cid_string(%CID{} = cid), do: to_string(cid)
  def cid_string("bafkr" <> _ = cid), do: cid

  @doc """
  Given a blob, saves it to the database.
  """
  def save(%__MODULE__{} = blob), do: Hexpds.Database.insert(blob)

  @doc """
  Given the DID of the owner of a blob,
  and the CID of the blob itself, this
  returns the blob itself in the database.
  Uses the hash to ensure uniqueness.
  """
  @spec get(Hexpds.CID.t() | String.t(), String.t()) :: t()
  def get(cid, "did:" <> _ = did) do
    hash = hash(did, cid_string(cid))

    Hexpds.Blob
    |> where(hash: ^hash)
    |> Hexpds.Database.one()
  end

  def get("did:" <> _ = did, cid), do: get(cid, did)

  @doc """
  Given a CID, returns all blobs that share that CID.
  (These blobs may be owned by different users, but
  should be identical otherwise).
  """
  @spec with_cid(Hexpds.CID.t()) :: [t()]
  def with_cid(cid) do
    Hexpds.Blob
    |> where(cid: ^cid)
    |> Hexpds.Database.all()
  end

  @doc """
  All blobs owned by the given user.
  """
  @spec of_user(Hexpds.User.t()) :: [t()]
  def of_user(%Hexpds.User{did: did}) do
    from(Hexpds.Blob, where: [did: ^did])
    |> Hexpds.Database.all()
  end
end
