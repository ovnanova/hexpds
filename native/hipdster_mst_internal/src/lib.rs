use rustler;

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
