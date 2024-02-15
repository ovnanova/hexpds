use rustler::Binary;
use rustler::Encoder;
use rustler::Env;
use rustler::Term;
use k256::elliptic_curve::sec1::ToEncodedPoint;
use k256::PublicKey;
use k256::SecretKey;
use hex;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn create_public_key<'a>(env: Env<'a>, private_key: Binary<'a>) -> Term<'a> {

    let secret_key = match SecretKey::from_slice(&private_key) {
        Ok(key) => key,
        Err(e) => return (atoms::error(), format!("Failed to create secret key: {}", e)).encode(env),
    };

    let public_key = secret_key.public_key();

    let public_key_hex = hex::encode(public_key.to_encoded_point(false).as_bytes());

    (atoms::ok(), public_key_hex).encode(env)
}

#[rustler::nif]
fn compress_public_key<'a>(env: Env<'a>, public_key: Binary<'a>) -> Term<'a> {
    let public_key = match hex::decode(public_key.as_slice()) {
        Ok(key) => key,
        Err(e) => return (atoms::error(), format!("Failed to decode hex string: {}", e)).encode(env),
    };

    let public_key = match PublicKey::from_sec1_bytes(&public_key) {
        Ok(key) => key,
        Err(e) => return (atoms::error(), format!("Failed to parse public key: {}", e)).encode(env),
    };

    let compressed_key = hex::encode(public_key.to_encoded_point(true).as_bytes());
    (atoms::ok(), compressed_key).encode(env)
}

rustler::init!("Elixir.Hexpds.K256.Internal", [create_public_key, compress_public_key]);

