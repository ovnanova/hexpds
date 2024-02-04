use rustler::{Encoder, Env, Term};
// use k256:: ...;
// use hex;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn create_public_key(env: Env, _private_key: String) -> Term {
    let response = "TO-DO: Implement creation logic";
    (atoms::ok(), response).encode(env)
}
rustler::init!("Elixir.Hexpds.K256", [create_public_key]);

