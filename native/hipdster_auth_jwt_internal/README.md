# NIF for Elixir.Hipdster.Auth.JWT.Internal

## To build the NIF module:

- Your NIF will now build along with your project.

## To load the NIF:

```elixir
defmodule Hipdster.Auth.JWT.Internal do
  use Rustler, otp_app: :hipdster, crate: "hipdster_auth_jwt_internal"

  # When your NIF is loaded, it will override this function.
  def generate_jwt(account_did, service_did, key, is_k256,), do: :erlang.nif_error(:nif_not_loaded)
end
```

## Examples

[This](https://github.com/rusterlium/NifIo) is a complete example of a NIF written in Rust.
