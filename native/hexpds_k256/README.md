# NIF for Elixir.Hexpds.k256

## To build the NIF module:

- Your NIF will now build along with your project.

## To load the NIF:

```elixir
defmodule Hexpds.K256 do
  use Rustler, otp_app: :hexpds, crate: "hexpds_k256"

  # When your NIF is loaded, it will override this function.
  def create_public_key(private_key), do: :erlang.nif_error(:nif_not_loaded)
end
```

## Examples

[This](https://github.com/rusterlium/NifIo) is a complete example of a NIF written in Rust.
