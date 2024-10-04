defmodule Hexpds.MST.Util do
  @moduledoc """
  Utility functions for MST operations.
  """

  alias Hexpds.DagCBOR.Internal
  alias Hexpds.CID
  alias Hexpds.MST.Node
  require Logger

  @doc """
  Serializes MST node entries into a CBOR binary with prefix compression.
  """
  @spec serialize_node_data([Node.t()], pid()) :: {:ok, binary()} | {:error, term()}
  def serialize_node_data(entries, _storage) do
    keys = Enum.map(entries, fn
      %Node{type: :leaf, key: key} -> key
      %Node{type: :internal} -> ""
    end)

    common_prefix = longest_common_prefix(keys)
    prefix_length = String.length(common_prefix)

    serialized_entries =
      Enum.map(entries, fn
        %Node{type: :internal, pointer: pointer} ->
          %{
            "p" => prefix_length,
            "k" => nil,
            "v" => nil,
            "t" => CID.to_string(pointer)
          }

        %Node{type: :leaf, key: key, value: %CID{} = value} ->
          suffix = remove_prefix(key, common_prefix)
          %{
            "p" => prefix_length,
            "k" => suffix,
            "v" => CID.to_string(value),
            "t" => nil
          }
      end)

    data_map = %{
      "prefix" => common_prefix,
      "entries" => serialized_entries
    }

    with {:ok, json_string} <- Jason.encode(data_map),
         {:ok, cbor_binary} <- Internal.encode_dag_cbor(json_string) do
      {:ok, cbor_binary}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deserializes a CBOR binary into MST node entries with prefix decompression.
  """
  @spec deserialize_node_data(binary(), pid()) :: {:ok, [Node.t()]} | {:error, term()}
  def deserialize_node_data(cbor, _storage) do
    with {:ok, json_string} <- Internal.decode_dag_cbor(cbor),
         {:ok, %{"prefix" => common_prefix, "entries" => serialized_entries}} <- Jason.decode(json_string) do
      reconstructed_entries =
        Enum.map(serialized_entries, fn entry ->
          cond do
            is_binary(entry["t"]) ->
              with {:ok, cid_struct} <- CID.from_string(entry["t"]) do
                %Node{type: :internal, pointer: cid_struct}
              else
                {:error, reason} ->
                  Logger.error("Failed to decode CID: #{reason}")
                  nil
              end

            is_binary(entry["k"]) and is_binary(entry["v"]) ->
              full_key = common_prefix <> entry["k"]
              with {:ok, value_cid} <- CID.from_string(entry["v"]) do
                %Node{type: :leaf, key: full_key, value: value_cid}
              else
                {:error, reason} ->
                  Logger.error("Failed to decode value CID: #{reason}")
                  nil
              end

            true ->
              Logger.error("Invalid entry format: #{inspect(entry)}")
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      {:ok, reconstructed_entries}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Determines the appropriate layer based on the entries.
  """
  @spec layer_for_entries([Node.t()]) :: {:ok, non_neg_integer()} | {:error, term()}
  def layer_for_entries(entries) when is_list(entries) do
    case entries do
      [] -> {:error, :no_entries}
      _ ->
        leading_zeros_list =
          entries
          |> Enum.map(fn
            %Node{type: :leaf, key: key} -> key
            %Node{type: :internal, pointer: pointer} -> CID.to_string(pointer)
          end)
          |> Enum.map(&leading_zeros_on_hash/1)
          |> Enum.map(fn
            {:ok, count} -> count
            {:error, _} -> 0
          end)

        {:ok, Enum.min(leading_zeros_list)}
    end
  end

  @doc """
  Determines the longest common prefix among a list of strings.
  """
  @spec longest_common_prefix([String.t()]) :: String.t()
  def longest_common_prefix([]), do: ""

  def longest_common_prefix([first | rest]) do
    Enum.reduce(rest, first, &common_prefix/2)
  end

  @doc """
  Finds the common prefix between two strings.
  """
  @spec common_prefix(String.t(), String.t()) :: String.t()
  def common_prefix(str1, str2) do
    str1
    |> String.graphemes()
    |> Enum.zip(String.graphemes(str2))
    |> Enum.take_while(fn {c1, c2} -> c1 == c2 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.join()
  end

  @doc """
  Removes the common prefix from a string.
  """
  @spec remove_prefix(String.t(), String.t()) :: String.t()
  def remove_prefix(str, prefix) do
    String.replace_prefix(str, prefix, "")
  end

  @doc """
  Ensures that the provided MST key is valid.
  """
  @spec ensure_valid_mst_key(String.t()) :: :ok | {:error, String.t()}
  def ensure_valid_mst_key(key) when is_binary(key) and byte_size(key) > 0, do: :ok
  def ensure_valid_mst_key(_), do: {:error, "MST key must be a non-empty string."}

  @doc """
  Calculates the number of leading zeros in the SHA-256 hash of the given key.
  """
  @spec leading_zeros_on_hash(String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def leading_zeros_on_hash(key) when is_binary(key) do
    try do
      <<hash::256>> = :crypto.hash(:sha256, key)
      leading_zeros = count_leading_zeros(hash)
      {:ok, leading_zeros}
    rescue
      e ->
        {:error, "Failed to compute leading zeros: #{inspect(e)}"}
    end
  end

  defp count_leading_zeros(<<0::1, rest::bitstring>>), do: 1 + count_leading_zeros(rest)
  defp count_leading_zeros(_), do: 0

  @doc """
  Generates a CID for the given entries.
  """
  @spec cid_for_entries([Node.t()], pid()) :: {:ok, CID.t()} | {:error, term()}
  def cid_for_entries(entries, _storage) do
    with {:ok, serialized} <- serialize_node_data(entries, nil),
         {:ok, cid} <- CID.create_cid(:sha256, serialized) do
      {:ok, cid}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
