defmodule Hexpds.DagCBOR do
  defmodule Internal do
    use Rustler, otp_app: :hexpds, crate: "hexpds_dagcbor_internal"
      @spec encode_dag_cbor(binary()) :: {:ok, binary()} | {:error, String.t()}
      def encode_dag_cbor(_json), do: :erlang.nif_error(:nif_not_loaded)
  end
end
