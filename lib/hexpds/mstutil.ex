defmodule Hexpds.MST.MSTUtil do
  @moduledoc """
  Utility functions for MST operations.
  """

  @spec ensure_valid_key(String.t()) :: :ok | no_return()
  def ensure_valid_key(key) do
    if String.length(key) > 0 do
      :ok
    else
      raise "Invalid key: Key must be a non-empty string."
    end
  end

  @spec leading_zeros_on_hash(String.t()) :: integer()
  def leading_zeros_on_hash(key) do
    hash = :crypto.hash(:sha256, key)
    hash
    |> :binary.bin_to_list()
    |> Enum.reduce_while(0, fn byte, acc ->
      case byte do
        0 -> {:cont, acc + 8}
        _ -> {:halt, acc + leading_zeros(byte)}
      end
    end)
  end

  @spec leading_zeros(integer()) :: integer()
  defp leading_zeros(byte) do
    bits = :erlang.integer_to_binary(byte, 2)
    String.length(String.trim_leading(bits, "0"))
  end

  @spec cid_for_entries(list()) :: binary()
  def cid_for_entries(entries) do
    data = serialize_node_data(entries)
    :crypto.hash(:sha256, data)
  end

  @spec serialize_node_data(list()) :: binary()
  def serialize_node_data(entries) do
    # CBOR serialization
    :erlang.term_to_binary(entries)
  end

  @spec deserialize_node_data(module(), binary()) :: list()
  def deserialize_node_data(_storage, data) do
    # CBOR deserialization
    :erlang.binary_to_term(data)
  end
end
