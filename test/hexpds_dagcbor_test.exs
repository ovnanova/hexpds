defmodule HexpdsDagcborTest do
  use ExUnit.Case
  doctest Hexpds.DagCBOR

  defp test_cases do
    [
      "test text",
      ["test text"],
      %{"string" => "test text"},
      %{"map" => %{"string" => "test text"}},
      %{"list" => ["text"]},
    ]
  end

  test "cbor roundtrip" do
    for input <- test_cases() do
      {:ok, cbor_encoded} = Hexpds.DagCBOR.encode(Jason.encode!(input))
      {:ok, json_encoded} = Hexpds.DagCBOR.decode_json(cbor_encoded)
      assert input == Jason.decode!(json_encoded)
    end
  end
end
