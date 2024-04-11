defmodule Hipdster.Auth.JWT do
  defmodule Internal do
    use Rustler, otp_app: :hipdster, crate: "hipdster_auth_jwt_internal"

    def generate_k256_jwt(_account_did, _service_did, _subject, _key),
      do: :erlang.nif_error(:nif_not_loaded)
    def generate_hs256_jwt(_account_did, _subject, _hs256_key, _time_in_minutes),
      do: :erlang.nif_error(:nif_not_loaded)
    def verify_hs256_jwt(_jwt, _key), do: :erlang.nif_error(:nif_not_loaded)
  end

  import Hipdster.Helpers

  @spec interservice(Hipdster.User.t(), Hipdster.Identity.did(), String.t()) :: {:ok, binary()} | {:error, String.t()}
  def interservice(
        %Hipdster.User{
          signing_key: %Hipdster.K256.PrivateKey{
            privkey: <<>> <> signing_key_bytes
          },
          did: user_did
        },
        service_did,
        subject \\ ""
      ) do
    Hipdster.Auth.JWT.Internal.generate_k256_jwt(
      user_did,
      service_did,
      subject,
      signing_key_bytes
    )
  end

  def! interservice(user, service_did, subject)
  def! interservice(user, service_did)

end
