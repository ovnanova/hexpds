defmodule Hexpds.K256 do
  defmodule PrivateKey do
    defstruct [:privkey]
    @type t :: %__MODULE__{privkey: <<_::256>>}

    @spec create() :: t()
    def create(), do: %__MODULE__{privkey: :crypto.strong_rand_bytes(32)}

    @spec from_binary(binary()) :: Hexpds.K256.PrivateKey.t()
    def from_binary(privkey), do: %__MODULE__{privkey: privkey}

    @spec from_hex(String.t()) :: Hexpds.K256.PrivateKey.t()
    def from_hex(hex), do: from_binary(Base.decode16!(hex, case: :lower))

    @spec to_hex(Hexpds.K256.PrivateKey.t()) :: String.t()
    def to_hex(%__MODULE__{} = privkey), do: Base.encode16(privkey.privkey, case: :lower)

    @spec to_pubkey(Hexpds.K256.PrivateKey.t()) :: Hexpds.K256.PublicKey.t()
    def to_pubkey(%__MODULE__{} = privkey), do: Hexpds.K256.PublicKey.create(privkey)

    @spec sign(Hexpds.K256.PrivateKey.t(), binary()) :: {:error, binary()} | {:ok, binary()}
    def sign(%__MODULE__{privkey: privkey}, message) do
      with {:ok, sig} <- Hexpds.K256.Internal.sign_message(privkey, message),
           do: {:ok, to_string(sig)}
    end
  end

  defmodule PublicKey do
    defstruct [:pubkey]
    @type t :: %__MODULE__{pubkey: <<_::256>>}

    @spec create(PrivateKey.t()) :: t()
    def create(%PrivateKey{privkey: privkey}) do
      case Hexpds.K256.Internal.create_public_key(privkey) do
        {:ok, pubkey} -> from_binary(pubkey)
        {:error, e} -> raise e
      end
    end

    def from_binary(pubkey), do: %__MODULE__{pubkey: pubkey}
    def from_hex(hex), do: from_binary(Base.decode16!(hex, case: :lower))

    @spec compress(Hexpds.K256.PublicKey.t()) :: binary()
    def compress(%__MODULE__{pubkey: pubkey}) do
      case Hexpds.K256.Internal.compress_public_key(pubkey) do
        {:ok, compressed} -> compressed
        {:error, e} -> raise e
      end
    end

    @spec to_did_key(Hexpds.K256.PublicKey.t()) :: String.t()
    def to_did_key(%__MODULE__{} = pubkey) do
      "did:key:" <>
        (pubkey
         |> compress()
         |> Base.decode16!(case: :lower)
         |> Hexpds.Multicodec.encode(:"secp256k1-pub")
         |> Multibase.encode!(:base58_btc))
    end
  end

  defmodule Internal do
    use Rustler, otp_app: :hexpds, crate: "hexpds_k256_internal"
      @spec create_public_key(binary()) :: {:ok, binary()} | {:error, String.t()}
      def create_public_key(_private_key), do: :erlang.nif_error(:nif_not_loaded)
      @spec compress_public_key(binary()) :: {:ok, binary()} | {:error, String.t()}
      def compress_public_key(_public_key), do: :erlang.nif_error(:nif_not_loaded)
      @spec sign_message(binary(), binary()) :: {:ok, binary()} | {:error, String.t()}
      def sign_message(_private_key, _message), do: :erlang.nif_error(:nif_not_loaded)
  end
end
