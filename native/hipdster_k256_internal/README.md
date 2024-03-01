# NIF for Elixir.Hipdster.K256.Internal

## To build the NIF module:

- Your NIF will now build along with your project.

## To load the NIF:

```elixir
defmodule Hipdster.K256.Internal do
  use Rustler, otp_app: :hipdster, crate: "hipdster_k256_internal"

  # When your NIF is loaded, it will override this function.
  def create_public_key(private_key), do: :erlang.nif_error(:nif_not_loaded)
  def compress_public_key(private_key), do: :erlang.nif_error(:nif_not_loaded)
end
```

## Examples

[This](https://github.com/rusterlium/NifIo) is a complete example of a NIF written in Rust.
