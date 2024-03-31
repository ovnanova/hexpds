#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

rustler::init!("Elixir.Hipdster.Auth.JWT.Internal", [add]);
