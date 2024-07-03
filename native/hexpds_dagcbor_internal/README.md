# NIF for Elixir.Hexpds.DagCBOR.Internal

## To build the NIF module:

- Your NIF will now build along with your project.

## To load the NIF:

```elixir
defmodule Hexpds.DagCBOR.Internal do
  use Rustler, otp_app: :hexpds, crate: "hexpds_dagcbor_internal"

  # When your NIF is loaded, it will override this function.
  def encode_dag_cbor(json), do: :erlang.nif_error(:nif_not_loaded)
end
```

## Examples

[This](https://github.com/rusterlium/NifIo) is a complete example of a NIF written in Rust.
