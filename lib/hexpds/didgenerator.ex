defmodule Hexpds.DidGenerator do
  require Logger
  alias Hexpds.K256, as: K256

  def sign_genesis(genesis, privkey) do
    # Sign the genesis block
  end

  def publish_to_plc(signed_genesis, plc_url) do
    # Publish the signed genesis to PLC using HTTPoison or Tesla
    {:ok, signed_genesis}
  end

  def generate_did() do
    privkey = K256.PrivateKey.create()
    # extract public key from privkey
    pubkey = K256.PublicKey.create(privkey)

    # define the genesis structure
    genesis = ""
    signed_genesis = sign_genesis(genesis, privkey)
    # define PLC URL
    plc_url = ""

    publish_to_plc(signed_genesis, plc_url)
  end
end
