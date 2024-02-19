defmodule Hexpds.K256 do
  @moduledoc """
  Secp256k1-related functions, using the `k256` Rust crate.
  Includes `Hexpds.K256.PrivateKey` and `Hexpds.K256.PublicKey`, which are type-safe wrappers around
  raw bytes of keys and include wrappers around the `k256` crate's `k256::PublicKey` and `k256::SecretKey` types
  and some of their helper functions required for ATProto.
  """
  defmodule PrivateKey do
    defstruct [:privkey]
    @type t :: %__MODULE__{privkey: <<_::256>>}

    defguard is_valid_key(privkey) when is_binary(privkey) and byte_size(privkey) == 32

    @spec create() :: t()
    def create(), do: %__MODULE__{privkey: :crypto.strong_rand_bytes(32)}

    @spec from_binary(binary()) :: t()
    def from_binary(privkey), do: %__MODULE__{privkey: privkey}

    @spec from_hex(String.t()) :: t()
    def from_hex(hex), do: from_binary(Base.decode16!(hex, case: :lower))

    @spec to_hex(t()) :: String.t()
    def to_hex(%__MODULE__{} = privkey), do: Base.encode16(privkey.privkey, case: :lower)

    @spec to_pubkey(t()) :: Hexpds.K256.PublicKey.t()
    def to_pubkey(%__MODULE__{} = privkey) when is_valid_key(privkey.privkey),
      do: Hexpds.K256.PublicKey.create(privkey)

    @spec sign(t(), binary()) :: {:error, String.t()} | binary()
    @doc """
    Signs a binary message with a Secp256k1 private key. Returns a binary signature.
    """
    def sign(%__MODULE__{privkey: privkey}, message) when is_binary(message) do
      with {:ok, sig_hex} <- Hexpds.K256.Internal.sign_message(privkey, message),
           {:ok, sig} <- Base.decode16(sig_hex, case: :lower),
           do: sig
    end

    @spec sign!(t(), binary()) :: binary()
    @doc """
    Signs a binary message with a Secp256k1 private key. Returns a binary signature. Raises on error if signing fails.
    """
    def sign!(%__MODULE__{} = privkey, message) do
      case sign(privkey, message) do
        {:error, e} -> raise e
        sig -> sig
      end
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

    @spec from_binary(binary()) :: Hexpds.K256.PublicKey.t()
    def from_binary(pubkey), do: %__MODULE__{pubkey: pubkey}
    @spec from_hex(binary()) :: Hexpds.K256.PublicKey.t()
    def from_hex(hex), do: from_binary(Base.decode16!(hex, case: :lower))

    @spec compress(Hexpds.K256.PublicKey.t()) :: binary()
    @doc """
    Compresses a Secp256k1 public key as defined in [SEC 1](https://www.secg.org/sec1-v2.pdf).

    Wrapper around the `k256` crate's `k256::PublicKey::compress` function.
    """
    def compress(%__MODULE__{pubkey: pubkey}) do
      case Hexpds.K256.Internal.compress_public_key(pubkey) do
        {:ok, compressed} -> compressed
        {:error, e} -> raise e
      end
    end

    @spec to_did_key(Hexpds.K256.PublicKey.t()) :: String.t()
    @doc """
    Encodes a Secp256k1 public key as a DID, using the did:key: method, in
    accordance with the [did:key: specification](https://w3c-ccg.github.io/did-method-key/).

    First, the public key is compressed as defined in [SEC 1](https://www.secg.org/sec1-v2.pdf).

    Then, the bytes <<0xE7, 0x01>> are prepended to the compressed public key, in accordance with
    the Multicodec codec for Secp256k1 public keys.

    Finally, the bytes are Base58 encoded and prepended with the did:key: method.
    """
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
    @moduledoc """
    NIF for Rust crate k256. Raw APIs, do not use directly. Instead, use the
    `Hexpds.K256.PublicKey` and `Hexpds.K256.PrivateKey` modules.
    """
    use Rustler, otp_app: :hexpds, crate: "hexpds_k256_internal"
    @spec create_public_key(binary()) :: {:ok, binary()} | {:error, String.t()}
    def create_public_key(_private_key), do: :erlang.nif_error(:nif_not_loaded)
    @spec compress_public_key(binary()) :: {:ok, binary()} | {:error, String.t()}
    def compress_public_key(_public_key), do: :erlang.nif_error(:nif_not_loaded)
    @spec sign_message(binary(), binary()) :: {:ok, binary()} | {:error, String.t()}
    def sign_message(_private_key, _message), do: :erlang.nif_error(:nif_not_loaded)
  end
end
