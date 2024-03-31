defmodule Hipdster.Auth.JWT do
  defmodule Internal do
    use Rustler, otp_app: :hipdster, crate: "hipdster_auth_jwt_internal"

  end
end
