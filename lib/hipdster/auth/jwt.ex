defmodule Hipdster.Auth.JWT do
  defmodule Internal do
    use Rustler, otp_app: :hipdster, crate: "hipdster_auth_jwt_internal"

    import Hipdster.Helpers

    def generate_k256_jwt(_account_did, _service_did, _subject, _key),
      do: :erlang.nif_error(:nif_not_loaded)

    def generate_hs256_jwt(_account_did, _subject, _hs256_key, _time_in_minutes),
      do: :erlang.nif_error(:nif_not_loaded)

    def!(generate_hs256_jwt(account_did, subject, hs256_key, time_in_minutes))

    def verify_hs256_jwt(_jwt, _key), do: :erlang.nif_error(:nif_not_loaded)
  end

  import Hipdster.Helpers

  @spec interservice(Hipdster.User.t(), Hipdster.Identity.did(), String.t()) ::
          {:ok, binary()} | {:error, String.t()}
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

  def!(interservice(user, service_did, subject))
  def!(interservice(user, service_did))

  def access_jwt(
        %Hipdster.User{did: did},
        app_password_name \\ "main",
        hs256_secret \\ Application.get_env(:hipdster, :jwt_key)
      ) do
    Hipdster.Auth.JWT.Internal.generate_hs256_jwt!(
      did,
      Jason.encode!(%{scope: "com.atproto.access", pwd: app_password_name}),
      hs256_secret,
      60
    )
  end

  def refresh_jwt(
        %Hipdster.User{did: did},
        app_password_name \\ "main",
        hs256_secret \\ Application.get_env(:hipdster, :jwt_key)
      ) do
    Hipdster.Auth.JWT.Internal.generate_hs256_jwt!(
      did,
      Jason.encode!(%{scope: "com.atproto.refresh", pwd: app_password_name}),
      hs256_secret,
      130_000
    )
  end

  def verify(jwt, hs256_secret \\ Application.get_env(:hipdster, :jwt_key)) do
    Hipdster.Auth.JWT.Internal.verify_hs256_jwt(jwt, hs256_secret)
    |> case do
      {:ok, json} ->
        Jason.decode!(json)
        |> then(fn %{"sub" => sub} = tok -> put_in(tok["sub"], Jason.decode!(sub)) end)

      {:error, _reason} = e ->
        e
    end
  end

  def is_valid_pwd?("main"), do: true
  def is_valid_pwd?(_), do: false

end
