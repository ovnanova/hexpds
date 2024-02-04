defmodule Hexpds.DidGenerator do
  require Logger
  alias :crypto, as: Crypto
  alias Hexpds.K256, as: K256

  def generate_private_key(), do: Crypto.strong_rand_bytes(32)

  @spec get_public_key(binary()) :: binary() | {:error, String.t()}
  def get_public_key(privkey) when is_binary(privkey) and byte_size(privkey) == 32 do
    case(K256.create_public_key(privkey)) do
      {:ok, pubkey} -> pubkey
      _ -> raise "Error generating public key"
    end
  end

  @spec multicodec_encode(binary(), :"secp256k1-pub") :: <<_::16, _::_*8>>
  def multicodec_encode(pubkey, :"secp256k1-pub") do
    <<0xE7, 0x01, pubkey::binary>>
  end

  @spec create_public_did_key(binary()) :: String.t()
  def create_public_did_key(pubkey) do
    "did:key:" <>
      (case pubkey |> K256.compress_public_key() do
         {:ok, pubkey} -> pubkey
         _ -> raise "Error compressing public key"
       end
       |> Base.decode16!(case: :lower)
       |> multicodec_encode(:"secp256k1-pub")
       |> Multibase.encode!(:base58_btc))
  end

  def sign_genesis(genesis, privkey) do
    # Sign the genesis block
  end

  def publish_to_plc(signed_genesis, plc_url) do
    # Publish the signed genesis to PLC using HTTPoison or Tesla
    {:ok, signed_genesis}
  end

  def generate_did() do
    privkey = generate_private_key()
    # extract public key from privkey
    pubkey = ""

    # define the genesis structure
    genesis = ""
    signed_genesis = sign_genesis(genesis, privkey)
    # define PLC URL
    plc_url = ""

    publish_to_plc(signed_genesis, plc_url)
  end
end
