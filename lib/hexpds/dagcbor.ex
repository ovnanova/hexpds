defmodule Hexpds.DagCBOR do
  defmodule Internal do
    use Rustler, otp_app: :hexpds, crate: "hexpds_dagcbor_internal"
      @spec encode_dag_cbor(binary()) :: {:ok, binary()} | {:error, String.t()}
      def encode_dag_cbor(_json), do: :erlang.nif_error(:nif_not_loaded)
      @spec decode_dag_cbor(binary()) :: {:ok, String.t()} | {:error, String.t()}
      def decode_dag_cbor(_cbor), do: :erlang.nif_error(:nif_not_loaded)
  end
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
