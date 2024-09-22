defmodule Hexpds.MST.Util do
  @moduledoc """
  Utility function module for MST operations
  """

  alias Hexpds.DagCBOR.Internal
  alias Hexpds.CID
  alias Hexpds.MST
  require Logger

  @doc """
  Serializes MST node entries into a CBOR binary with prefix compression

  ## Parameters

    - `entries`: List of MST node entries (`%MST{}` or `%MST.Leaf{}` structs)
    - `storage`: PID of the storage module

  ## Returns

    - `{:ok, binary}` on success
    - `{:error, reason}` on failure
  """
  @spec serialize_node_data([MST.node_entry()], pid()) :: {:ok, binary()} | {:error, term()}
  def serialize_node_data(entries, storage) do
    keys = Enum.map(entries, fn
      %MST.Leaf{key: key} -> key
      %MST{} -> ""  # Subtrees use the common prefix
    end)

    common_prefix = longest_common_prefix(keys)
    prefix_length = String.length(common_prefix)

    serialized_entries =
      Enum.map(entries, fn
        %MST{} = subtree ->
          %{
            "p" => prefix_length,
            "k" => nil,
            "v" => nil,
            "t" => CID.encode!(subtree.pointer, :base32_lower)  # Assuming `pointer` holds the CID
          }

        %MST.Leaf{key: key, value: %CID{} = value} ->
          suffix = remove_prefix(key, common_prefix)
          %{
            "p" => prefix_length,
            "k" => suffix,
            "v" => CID.encode!(value, :base32_lower),
            "t" => nil
          }
      end)

    # Construct the data map
    data_map = %{
      "prefix" => common_prefix,
      "entries" => serialized_entries
    }

    # Encode the data map to JSON string
    case Jason.encode(data_map) do
      {:ok, json_string} ->
        # Call the Rust NIF to encode JSON to DAG-CBOR
        case Internal.encode_dag_cbor(json_string) do
          {:ok, cbor_binary} ->
            {:ok, cbor_binary}

          {:error, reason} ->
            {:error, "Failed to encode DAG-CBOR via NIF: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to encode data map to JSON: #{reason}"}
    end
  end

  @doc """
  Deserializes a CBOR binary into MST node entries with prefix decompression

  ## Parameters

    - `cbor`: Binary data in DAG-CBOR format
    - `storage`: PID of the storage module
    - `mst`: The current MST node (used for context)

  ## Returns

    - `{:ok, entries}` on success
    - `{:error, reason}` on failure
  """
  @spec deserialize_node_data(binary(), pid(), MST.t()) :: {:ok, [MST.node_entry()]} | {:error, term()}
  def deserialize_node_data(cbor, storage, mst) do
    # Call the Rust NIF to decode DAG-CBOR to JSON string
    case Internal.decode_dag_cbor(cbor) do
      {:ok, json_string} ->
        # Parse the JSON string to a map
        case Jason.decode(json_string) do
          {:ok, %{"prefix" => common_prefix, "entries" => serialized_entries}} ->
            # Reconstruct entries
            reconstructed_entries =
              Enum.map(serialized_entries, fn entry ->
                cond do
                  Map.has_key?(entry, "t") and is_binary(entry["t"]) ->
                    # Subtree entry
                    case CID.decode(entry["t"]) do
                      {:ok, cid_struct} ->
                        # Load the subtree MST node
                        case MST.load(storage, cid_struct) do
                          %MST{} = subtree ->
                            subtree

                          _ ->
                            Logger.error("Failed to load subtree with CID: #{entry["t"]}")
                            nil
                        end

                      {:error, reason} ->
                        Logger.error("Failed to decode CID from string: #{entry["t"]}, reason: #{reason}")
                        nil
                    end

                  Map.has_key?(entry, "k") and Map.has_key?(entry, "v") ->
                    # Leaf entry
                    full_key = common_prefix <> entry["k"]

                    case CID.decode(entry["v"]) do
                      {:ok, value_cid} ->
                        %MST.Leaf{key: full_key, value: value_cid}

                      {:error, reason} ->
                        Logger.error("Failed to decode value CID for key #{full_key}: #{reason}")
                        nil
                    end

                  true ->
                    Logger.error("Invalid entry format: #{inspect(entry)}")
                    nil
                end
              end)
              |> Enum.reject(&is_nil/1)

            {:ok, reconstructed_entries}

          {:error, reason} ->
            {:error, "Failed to parse JSON string: #{reason}"}

          _ ->
            {:error, "Malformed JSON data from DAG-CBOR decoding"}
        end

      {:error, reason} ->
        {:error, "Failed to decode DAG-CBOR via NIF: #{reason}"}
    end
  end

  @doc """
  Determines the longest common prefix among a list of strings

  ## Parameters

    - `keys`: List of strings

  ## Returns

    - `String.t()`: The longest common prefix
  """
  @spec longest_common_prefix([String.t()]) :: String.t()
  def longest_common_prefix([]), do: ""

  def longest_common_prefix([first | rest]) do
    Enum.reduce(rest, first, fn str, acc ->
      common_prefix(acc, str)
    end)
  end

  @doc """
  Finds the common prefix between two strings

  ## Parameters

    - `str1`: First string
    - `str2`: Second string

  ## Returns

    - `String.t()`: The common prefix
  """
  @spec common_prefix(String.t(), String.t()) :: String.t()
  def common_prefix(str1, str2) do
    do_common_prefix(String.graphemes(str1), String.graphemes(str2), [])
    |> Enum.reverse()
    |> Enum.join()
  end

  defp do_common_prefix([h1 | t1], [h2 | t2], acc) when h1 == h2 do
    do_common_prefix(t1, t2, [h1 | acc])
  end

  defp do_common_prefix(_, _, acc), do: acc

  @doc """
  Removes the common prefix from a string

  ## Parameters

    - `str`: The original string
    - `prefix`: The prefix to remove

  ## Returns

    - `String.t()`: The string after removing the prefix
  """
  @spec remove_prefix(String.t(), String.t()) :: String.t()
  def remove_prefix(str, prefix) do
    String.replace_prefix(str, prefix, "")
  end

  @doc """
  Ensures that the provided MST key is valid

  ## Parameters

    - `key`: The key to validate

  ## Returns

    - `:ok` if the key is valid
    - `{:error, reason}` if the key is invalid
  """
  @spec ensure_valid_mst_key(String.t()) :: :ok | {:error, String.t()}
  def ensure_valid_mst_key(key) when is_binary(key) and byte_size(key) > 0 do
    # Example validation: keys must start with "key" followed by digits
    if Regex.match?(~r/^key\d+$/, key) do
      :ok
    else
      {:error, "Invalid MST key format: #{key}. Keys must match the pattern /^key\\d+$/."}
    end
  end

  def ensure_valid_mst_key(_key), do: {:error, "MST key must be a non-empty string."}

  @doc """
  Calculates the number of leading zeros in the SHA-256 hash of the given key

  ## Parameters

    - `key`: The key to hash

  ## Returns

    - `{:ok, count}` where `count` is the number of leading zero bits
    - `{:error, reason}` if hashing fails
  """
  @spec leading_zeros_on_hash(String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def leading_zeros_on_hash(key) when is_binary(key) do
    # Compute SHA-256 hash
    hash = :crypto.hash(:sha256, key)

    # Convert hash to bitstring
    bitstring = :binary.bin_to_list(hash)
               |> Enum.map(&Integer.to_string(&1, 2) |> String.pad_leading(8, "0"))
               |> Enum.join()

    # Count leading zeros
    leading_zeros = String.length(bitstring) - String.length(String.trim_leading(bitstring, "0"))

    {:ok, leading_zeros}
  rescue
    e ->
      {:error, "Failed to compute leading zeros: #{inspect(e)}"}
  end

  def leading_zeros_on_hash(_key), do: {:error, "Key must be a binary (string)."}

  @doc """
  Generates a CID for the given entries

  ## Parameters

    - `entries`: List of MST node entries
    - `storage`: PID of the storage module

  ## Returns

    - `{:ok, CID.t()}` on success
    - `{:error, reason}` on failure
  """
  @spec cid_for_entries([MST.node_entry()], pid()) :: {:ok, CID.t()} | {:error, term()}
  def cid_for_entries(entries, storage) do
    with {:ok, serialized} <- serialize_node_data(entries, storage),
         {:ok, cid} <- CID.cid(serialized, "dag-cbor", 1) do
      {:ok, cid}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Failed to generate CID for entries"}
    end
  end
end
