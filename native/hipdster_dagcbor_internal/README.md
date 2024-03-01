# NIF for Elixir.Hipdster.DagCBOR.Internal

## To build the NIF module:

- Your NIF will now build along with your project.

## To load the NIF:

```elixir
defmodule Hipdster.DagCBOR.Internal do
  use Rustler, otp_app: :hipdster, crate: "hipdster_dagcbor_internal"

  # When your NIF is loaded, it will override this function.
  def encode_dag_cbor(json), do: :erlang.nif_error(:nif_not_loaded)
end
```

## Examples

[This](https://github.com/rusterlium/NifIo) is a complete example of a NIF written in Rust.
