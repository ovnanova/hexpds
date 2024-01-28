defmodule Hexpds.DidGenerator do
  require Logger
  alias :libsecp256k1, as: Secp256k1
  alias :base64, as: Base64
  alias :cbor, as: CBOR

  def generate_private_key() do
    # Generate private key using libsecp256k1 or ex_crypto
  end

  def create_did_web_pubkey(pubkey) do
    # Convert public key to the required format and encode
  end

  def sign_genesis(genesis, privkey) do
    # Sign the genesis block
  end

  def publish_to_plc(signed_genesis, plc_url) do
    # Publish the signed genesis to PLC using HTTPoison or Tesla
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
