defmodule Hexpds.K256 do
  @moduledoc """
  Secp256k1-related functions, using the `k256` Rust crate.
  Includes `Hexpds.K256.PrivateKey` and `Hexpds.K256.PublicKey`, which are type-safe wrappers around
  raw bytes of keys and include wrappers around the `k256` crate's `k256::PublicKey` and `k256::SecretKey` types
  and some of their helper functions required for ATProto.
  """

  defmodule Signature do
    @moduledoc """
    An ECDSA signature along the Secp256k1 curve.
    Should be 64 bytes (512 bits) long.
    """
    defstruct [:sig]
    @type t :: %__MODULE__{sig: <<_::512>>}

    @spec create(binary()) :: t()
    def create(sig), do: %__MODULE__{sig: sig}

    def bytes(%__MODULE__{sig: sig}), do: sig
    def bytes({:error, e}), do: raise(e)

    @spec verify(t(), Hexpds.K256.PublicKey.t(), binary()) ::
            {:ok, String.t()} | {:error, String.t()}
    def verify(
          %__MODULE__{sig: sig},
          %{pubkey: pubkey, __struct__: Hexpds.K256.PublicKey},
          message
        ) do
      pubkey
      |> Base.encode16()
      |> Hexpds.K256.Internal.verify_signature(message, sig)
      |> case do
        true -> {:ok, "Signature #{inspect(sig)} verified"}
        false -> {:error, "Signature #{inspect(sig)} could not be verified"}
        tuple -> tuple
      end
    end
  end

  defmodule PrivateKey do
    defstruct [:privkey]

    @typedoc """
    A Secp256k1 private key. Contains the raw bytes of the key, and wraps the `k256` crate's `k256::SecretKey` type.
    Should always be 32 bytes (256 bits) long. All operations on `Hexpds.K256.PrivateKey` are type-safe.
    """
    @type t :: %__MODULE__{privkey: <<_::256>>}

    defguard is_valid_key(privkey) when is_binary(privkey) and byte_size(privkey) == 32

    @spec create() :: t()
    @doc """
    Generates a new Secp256k1 private key.
    """
    def create(), do: %__MODULE__{privkey: :crypto.strong_rand_bytes(32)}

    @spec from_binary(binary()) :: t()

    @doc """
    Wraps a Secp256k1 private key from its raw bytes.
    """
    def from_binary(privkey) when is_valid_key(privkey), do: %__MODULE__{privkey: privkey}

    @spec from_hex(String.t()) :: t()
    def from_hex(hex), do: from_binary(Base.decode16!(hex, case: :lower))

    @spec to_hex(t()) :: String.t()

    @doc """
    Converts a Secp256k1 private key to a hex-encoded string.
    """
    def to_hex(%__MODULE__{privkey: privkey}) when is_valid_key(privkey),
      do: Base.encode16(privkey, case: :lower)

    @spec to_pubkey(t()) :: Hexpds.K256.PublicKey.t()
    def to_pubkey(%__MODULE__{} = privkey) when is_valid_key(privkey.privkey),
      do: Hexpds.K256.PublicKey.create(privkey)

    @spec sign(t(), binary()) :: {:error, String.t()} | Hexpds.K256.Signature.t()
    @doc """
    Signs a binary message with a Secp256k1 private key. Returns a binary signature.
    """
    def sign(%{privkey: privkey}, message)
        when is_binary(message) and is_valid_key(privkey) do
      with {:ok, sig} <- Hexpds.K256.Internal.sign_message(privkey, message),
           {:ok, sig_bytes} <- Base.decode16(sig, case: :lower),
           do: %Hexpds.K256.Signature{sig: sig_bytes}
    end

    @spec sign!(t(), binary()) :: Hexpds.K256.Signature.t()
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

    # Right now these seem to be storing public keys
    # in hex format rather than as bytes.
    # We probably want to change this at some point,
    # for consistency with PrivateKey.

    @spec create(PrivateKey.t()) :: t()
    def create(%PrivateKey{privkey: privkey}) do
      case Hexpds.K256.Internal.create_public_key(privkey) do
        {:ok, pubkey} -> from_hex(pubkey)
        {:error, e} -> raise e
      end
    end

    @spec from_binary(binary()) :: t()
    def from_binary(pubkey), do: %__MODULE__{pubkey: pubkey}
    @spec from_hex(binary()) :: t()
    def from_hex(hex), do: from_binary(Base.decode16!(hex, case: :lower))

    @spec compress(t()) :: binary()
    @doc """
    Compresses a Secp256k1 public key as defined in [SEC 1](https://www.secg.org/sec1-v2.pdf).

    Wrapper around the `k256` crate's `k256::PublicKey::compress` function.
    """
    def compress(%__MODULE__{pubkey: pubkey}) do
      Base.encode16(pubkey, case: :lower)
      |> Hexpds.K256.Internal.compress_public_key()
      |> case do
        {:ok, compressed} -> compressed
        {:error, e} -> raise e
      end
    end

    @spec to_did_key(t()) :: String.t()
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
         |> Hexpds.Multicodec.encode!(:"secp256k1-pub")
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
    @spec verify_signature(binary(), binary(), binary()) :: boolean() | {:error, String.t()}
    def verify_signature(_public_key, _message, _signature),
      do: :erlang.nif_error(:nif_not_loaded)
  end
end
