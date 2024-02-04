defmodule Hexpds.K256 do
  use Rustler, otp_app: :hexpds, crate: "hexpds_k256"
    def create_public_key(private_key), do: :erlang.nif_error(:nif_not_loaded)
    def compress_public_key(public_key), do: :erlang.nif_error(:nif_not_loaded)
end
