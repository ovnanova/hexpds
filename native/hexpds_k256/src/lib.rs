use rustler::{Encoder, Env, Term};
use k256::{elliptic_curve::sec1::ToEncodedPoint, SecretKey};
use hex;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn create_public_key(env: Env, private_key: String) -> Term {
    let private_key_bytes = match hex::decode(&private_key) {
        Ok(bytes) => bytes,
        Err(e) => return (atoms::error(), format!("Failed to decode hex string: {}", e)).encode(env),
    };

    let secret_key = match SecretKey::from_be_bytes(&private_key_bytes) {
        Ok(key) => key,
        Err(e) => return (atoms::error(), format!("Failed to create secret key: {}", e)).encode(env),
    };

    let public_key = secret_key.public_key();

    let public_key_hex = hex::encode(public_key.to_encoded_point(false).as_bytes());

    (atoms::ok(), public_key_hex).encode(env)
}

rustler::init!("Elixir.Hexpds.K256", [create_public_key]);

