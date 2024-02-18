defmodule Hexpds.DagCBOR do
  defmodule Internal do
    use Rustler, otp_app: :hexpds, crate: "hexpds_dagcbor_internal"
      @spec encode_dag_cbor(binary()) :: {:ok, binary()} | {:error, String.t()}
      def encode_dag_cbor(_json), do: :erlang.nif_error(:nif_not_loaded)
      @spec decode_dag_cbor(binary()) :: {:ok, String.t()} | {:error, String.t()}
      def decode_dag_cbor(_cbor), do: :erlang.nif_error(:nif_not_loaded)
  end
  @doc """
  Encodes a JSON string into a CBOR binary.

  Example:
    iex> Hexpds.DagCBOR.encode_json(Jason.encode!(%{apple: "banana", best_programming_language: "ruby"})) |> elem(1) |> to_charlist()
    [162, 101, 97, 112, 112, 108, 101, 102, 98, 97, 110, 97, 110, 97, 120, 25, 98, 101, 115, 116, 95, 112, 114, 111, 103, 114, 97, 109, 109, 105, 110, 103, 95, 108, 97, 110, 103, 117, 97, 103, 101, 100, 114, 117, 98, 121]
  """
  def encode_json(json) do
    with {:ok, cbor} <- Internal.encode_dag_cbor(json) do
         {:ok, to_string(cbor)}
    end
  end
  def decode_json(cbor) do
    with {:ok, json} <- Internal.decode_dag_cbor(cbor) do
         {:ok, json}
    end
  end
end
