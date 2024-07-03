defmodule Hexpds.RecordConverter do
  # I'm unsure if we really need this in a separate module.
  # I also think the function names are a bit confusing.
  # Perhaps these could be a part of `Hexpds.Record` whenever we get there or something.
  # Leaving it here for now

  @moduledoc """
  From picopds/record_serde.py (with slight terminology changes):

  "record" object is elixir term representation of a dag_cbor blob.
  CIDs are represented with the Hexpds.CID struct.

  a "json" object is also a elixir term representation, but CIDs are referenced as {"$link": ...}
  (and non-json-representable types, like bytes, are forbidden)
  """

  alias Hexpds.CID, as: CID

  def record_to_json([] = record), do: Enum.map(record, &record_to_json/1)

  def record_to_json(%{} = record) do
    for {k, v} <- record, into: %{}, do: {k, record_to_json(v)}
  end

  def record_to_json(%CID{} = cid), do: %{"$link" => CID.encode!(cid, :base32_lower)}
  def record_to_json(<<>>), do: raise(ArgumentError, "can't represent bytes as JSON")
  def record_to_json(record), do: record

  def enumerate_record_cids([] = record), do: Enum.flat_map(record, &enumerate_record_cids/1)

  def enumerate_record_cids(%{} = record) do
    for {_k, v} <- record,
        into: [],
        do:
          enumerate_record_cids(v)
          |> List.flatten()
  end

  def enumerate_record_cids(%CID{} = cid), do: [cid]
  def enumerate_record_cids(_), do: []

  # Converts JSON data to a record format.
  def json_to_record([] = data), do: Enum.map(data, &json_to_record/1)
  def json_to_record({%{"$link" => link} = d}) when map_size(d) == 1, do: CID.decode!(link)

  def json_to_record(%{} = data) do
    for {k, v} <- data, into: %{}, do: {k, json_to_record(v)}
  end

  def json_to_record(d), do: d
end
