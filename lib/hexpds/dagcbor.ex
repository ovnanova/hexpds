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
    iex> Hexpds.DagCBOR.encode_json(Jason.encode!(%{apple: "banana", cranberry: "dragonfruit"})) |> elem(1) |> Base.encode16()
    "C2A2656170706C656662616E616E61696372616E62657272796B647261676F6E6672756974"
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
