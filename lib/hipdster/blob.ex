defmodule Hipdster.Blob do
  @moduledoc """
  An ATProto blob. Has a CID, mime-type, raw data, DID of the owner.
  A list of references will likely be added once we have repos working.
  """
  alias Hipdster.CID

  use Memento.Table,
    attributes: [:cid, :mime_type, :data, :did],
    index: [:did],
    type: :set

  @type t :: %__MODULE__{
          cid: Hipdster.CID.t(),
          mime_type: String.t(),
          data: binary(),
          did: Hipdster.Identity.did()
        }

  def errorcheck({:ok, data}), do: data
  def errorcheck({:error, reason}), do: raise(reason)

  def new(raw_bytes, %Hipdster.Auth.User{did: did}) do
    %__MODULE__{
      cid:
        Multihash.encode(:sha2_256, :crypto.hash(:sha256, raw_bytes))
        |> errorcheck()
        |> CID.cid!("raw"),
      mime_type: get_mime_type(raw_bytes),
      data: raw_bytes,
      did: did
    }
  end

  defp get_mime_type(data) do
    with %Infer.Type{mime_type: mime_type} <- Infer.get(data) do
      mime_type
    else
      _ -> "application/octet-stream"
    end
  end

  @spec cid_string(Hipdster.Blob.t()) :: binary()
  def cid_string(%__MODULE__{cid: cid}) do
    Hipdster.CID.encode!(cid, :base32_lower)
  end

  def save(%__MODULE__{} = blob) do
    Memento.transaction(fn ->
      Memento.Query.write(blob)
    end)
  end

  def get(cid) do
    with {cid, :base32_lower} <- Hipdster.CID.decode!(cid),
         {:ok, blob} <-
           Memento.transaction(fn ->
             Memento.Query.read(Hipdster.Blob, cid)
           end) do
      blob
    end
  end

  def of_user(%Hipdster.Auth.User{did: did}) do
    with {:ok, blobs} <- Memento.transaction(fn ->
      :mnesia.index_read(Hipdster.Blob, did, :did)
    end),
         do: blobs |> Enum.map(&Memento.Query.Data.load/1)
  end

end
