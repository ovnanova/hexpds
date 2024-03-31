defmodule Hipdster.Auth.JWT do
  defmodule Internal do
    use Rustler, otp_app: :hipdster, crate: "hipdster_auth_jwt_internal"

    # Temp to satisfy Rustler
    def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
  end
end
