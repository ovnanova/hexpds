defmodule Hexpds.K256_Internal do
  use Rustler, otp_app: :hexpds, crate: "hexpds_k256_internal"
    def create_public_key(private_key), do: :erlang.nif_error(:nif_not_loaded)
    def compress_public_key(public_key), do: :erlang.nif_error(:nif_not_loaded)
end
