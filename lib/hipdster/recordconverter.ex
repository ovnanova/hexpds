defmodule RecordConverter do
  alias Hipdster.CID, as: CID

  # Converts a record to a JSON-compatible format.
  def record_to_json(record) do
    cond do
      is_list(record) ->
        Enum.map(record, &record_to_json/1)

      is_map(record) ->
        Enum.reduce(record, %{}, fn {k, v}, acc ->
          Map.put(acc, k, record_to_json(v))
        end)

      # Assuming CID module exists with an encode function
      record.__struct__ == CID ->
        %{"$link" => CID.encode(record, "base32")}

      is_binary(record) ->
        raise ArgumentError, "can't represent bytes as JSON"

      true ->
        record
    end
  end

  # Enumerates CIDs within a record.
  def enumerate_record_cids(record) do
    cond do
      is_list(record) ->
        Enum.flat_map(record, &enumerate_record_cids/1)

      is_map(record) ->
        Enum.flat_map(record, fn {_k, v} -> enumerate_record_cids(v) end)

      record.__struct__ == CID ->
        [record]

      true ->
        []
    end
  end

  # Converts JSON data to a record format.
  def json_to_record(data) do
    cond do
      is_list(data) ->
        Enum.map(data, &json_to_record/1)

      is_map(data) ->
        if Kernel.map_size(data) == 1 and Map.has_key?(data, "$link") do
          # Assuming CID module exists with a decode function
          CID.decode(data["$link"])
        else
          Enum.reduce(data, %{}, fn {k, v}, acc ->
            Map.put(acc, k, json_to_record(v))
          end)
        end

      true ->
        data
    end
  end
end
