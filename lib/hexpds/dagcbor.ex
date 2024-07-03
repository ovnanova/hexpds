defmodule Hexpds.DagCBOR do
  defmodule Internal do
    use Rustler, otp_app: :hexpds, crate: "hexpds_dagcbor_internal"
    @spec encode_dag_cbor(binary()) :: {:ok, binary()} | {:error, String.t()}
    def encode_dag_cbor(_json), do: :erlang.nif_error(:nif_not_loaded)
    @spec decode_dag_cbor(binary()) :: {:ok, String.t()} | {:error, String.t()}
    def decode_dag_cbor(_cbor), do: :erlang.nif_error(:nif_not_loaded)
  end

  @spec encode(binary() | map()) :: {:error, binary()} | {:ok, binary()}
  @doc """
  Encodes a JSON string or a map into a CBOR binary.

  Examples:

      iex> Hexpds.DagCBOR.encode(%{apple: "banana", cranberry: "dragonfruit"})
      ...> |> elem(1)
      ...> |> Base.encode16()
      "A2656170706C656662616E616E61696372616E62657272796B647261676F6E6672756974"

  """
  def encode("" <> json) do
    with {:ok, cbor} <- Internal.encode_dag_cbor(json) do
      {:ok, to_string(cbor)}
    end
  end

  def encode(%{} = json) do
    with {:ok, json} <- Jason.encode(json), do: encode(json)
  end

  def encode([_ | _] = l) do
    with {:ok, json} <- Jason.encode(l), do: encode(json)
  end

  @doc """
  Decodes a CBOR binary into a JSON string.
  """
  @spec decode_json(binary()) :: {:error, binary()} | {:ok, String.t()}
  def decode_json(cbor) do
    Internal.decode_dag_cbor(cbor)
  end

  @doc """
  Decodes a CBOR binary into an erlang term.
  Examples:

      iex> Hexpds.DagCBOR.decode(<<131,0,3,4>>)
      ...> |> elem(1)
      [0, 3, 4]
  """
  @spec decode(binary()) :: {:error, binary() | Jason.DecodeError.t()} | {:ok, any()}
  def decode(cbor) do
    with {:ok, json} <- decode_json(cbor), do: Jason.decode(json)
  end
end
