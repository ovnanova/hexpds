defmodule Hexpds.DidGenerator do
  require Logger
  alias :crypto, as: Crypto
  alias ExSecp256k1, as: Secp256k1

  def generate_private_key(), do: Crypto.strong_rand_bytes(32)

  @spec get_public_key(binary()) :: binary() | {:error, String.t()}
  def get_public_key(privkey) when is_binary(privkey) and byte_size(privkey) == 32 do
    case(Secp256k1.create_public_key(privkey)) do
      {:ok, pubkey} -> pubkey
      _ -> {:error, "Invalid private key"}
    end
  end

  def create_public_did_key(pubkey) do
    # Convert public key to the required format and encode
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
