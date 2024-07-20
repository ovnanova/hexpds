defmodule Hexpds.Repo.Helpers do
  alias Hexpds.{DagCBOR, CID}

  def dagcbor_cid(encoded_dagcbor) do
    :crypto.hash(:sha256, encoded_dagcbor)
    |> CID.cid!("dag-cbor")
  end

  def cid_string(%Hexpds.CID{} = cid) do
    CID.encode!(cid, :base32_lower)
  end

  def term_to_dagcbor_cid(term, [string: stringify] \\ [string: true]) do
    DagCBOR.encode!(term)
    |> dagcbor_cid()
    |> then(fn encoded -> {encoded, stringify} end)
    |> case do
      {encoded, true} -> cid_string(encoded)
      {encoded, false} -> encoded
      _ -> {:error, "term_to_dagcbor_cid got string: #{inspect(stringify)} but stringify must be a bool"}
    end
  end

end
