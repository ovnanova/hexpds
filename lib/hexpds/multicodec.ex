defmodule Hexpds.Multicodec do
  @spec encode(binary(), :"secp256k1-pub") :: binary()
  def encode(pubkey, :"secp256k1-pub") do
    <<0xE7, 0x01, pubkey::binary>>
  end
end
