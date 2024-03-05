use rustler;

// TBD
// We might not end up using this, but leaving it here for now
// in case that there are MST-specific operations we need to create NIFs for.

// Current, we know we need DAG-CBOR,
// but we can reuse the existing NIF crate for that

// Ideally, our Rust crates will be more limited in scope to emphasize
// explicitness and reusability, i.e. perform specific tasks rather than
// something like this; a general helper for a class.

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn stuff() {
    todo!();
}

rustler::init!("Elixir.Hipdster.MST.Internal", [stuff]);
