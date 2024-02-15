defmodule Hexpds.K256.Internal do
  use Rustler, otp_app: :hexpds, crate: "hexpds_k256_internal"
    @spec create_public_key(binary()) :: {:ok, binary()} | {:error, String.t()}
    def create_public_key(_private_key), do: :erlang.nif_error(:nif_not_loaded)
    @spec compress_public_key(binary()) :: {:ok, binary()} | {:error, String.t()}
    def compress_public_key(_public_key), do: :erlang.nif_error(:nif_not_loaded)
end
