defmodule HipdsterDagcborTest do
  use ExUnit.Case
  doctest Hipdster.DagCBOR

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
      {:ok, cbor_encoded} = Hipdster.DagCBOR.encode(Jason.encode!(input))
      {:ok, original} = Hipdster.DagCBOR.decode(cbor_encoded)
      assert input == original
    end
  end
end
