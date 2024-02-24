use hex;
use k256::ecdsa::signature::Signer;
use k256::elliptic_curve::sec1::ToEncodedPoint;
use rustler::Binary;
use rustler::Encoder;
use rustler::Env;
use rustler::Term;
use k256::ecdsa::signature::Verifier;


mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn create_public_key<'a>(env: Env<'a>, private_key: Binary<'a>) -> Term<'a> {
    let secret_key = match k256::SecretKey::from_slice(&private_key) {
        Ok(key) => key,
        Err(e) => {
            return (
                atoms::error(),
                format!("Failed to create secret key: {}", e),
            )
                .encode(env)
        }
    };

    let public_key = secret_key.public_key();

    let public_key_hex = hex::encode(public_key.to_encoded_point(false).as_bytes());

    (atoms::ok(), public_key_hex).encode(env)
}

#[rustler::nif]
fn compress_public_key<'a>(env: Env<'a>, public_key: Binary<'a>) -> Term<'a> {
    let public_key = match hex::decode(public_key.as_slice()) {
        Ok(key) => key,
        Err(e) => {
            return (
                atoms::error(),
                format!("Failed to decode hex string: {}", e),
            )
                .encode(env)
        }
    };

    let public_key = match k256::PublicKey::from_sec1_bytes(&public_key) {
        Ok(key) => key,
        Err(e) => {
            return (atoms::error(), format!("Failed to parse public key: {}", e)).encode(env)
        }
    };

    let compressed_key = hex::encode(public_key.to_encoded_point(true).as_bytes());
    (atoms::ok(), compressed_key).encode(env)
}

#[rustler::nif]
fn sign_message<'a>(env: Env<'a>, private_key: Binary<'a>, message: Binary<'a>) -> Term<'a> {
    let signing_key = match k256::ecdsa::SigningKey::from_slice(&private_key) {
        Ok(key) => key,
        Err(e) => {
            return (
                atoms::error(),
                format!("Failed to create secret key: {}", e),
            )
                .encode(env)
        }
    };

    let signature: k256::ecdsa::Signature = signing_key.sign(message.as_slice());

    let signature_low_s: k256::ecdsa::Signature = match signature.normalize_s() {
        None => signature,
        Some(normalized) => normalized,
    };

    let signature_bytes = signature_low_s.to_bytes();

    let signature_hex = hex::encode(signature_bytes);

    (atoms::ok(), signature_hex).encode(env)
}

#[rustler::nif]
fn verify_signature<'a>(
    env: Env<'a>,
    public_key: Binary<'a>,
    message: Binary<'a>,
    signature_bin: Binary<'a>,
) -> Term<'a> {
    let public_key = match hex::decode(public_key.as_slice()) {
        Ok(key) => key,
        Err(e) => {
            return (
                atoms::error(),
                format!("Failed to decode hex string: {}", e),
            )
                .encode(env)
        }
    };

    let public_key = match k256::PublicKey::from_sec1_bytes(&public_key) {
        Ok(key) => key,
        Err(e) => {
            return (atoms::error(), format!("Failed to parse public key: {}", e)).encode(env)
        }
    };

    // Signature should be in bytes

    let signature = match k256::ecdsa::Signature::from_slice(signature_bin.as_slice()) {
        Ok(sig) => sig,
        Err(e) => return (atoms::error(), format!("Failed to parse signature: {}", e)).encode(env),
    };


    let verifying_key = k256::ecdsa::VerifyingKey::from(public_key);
    let verified = verifying_key.verify(message.as_slice(), &signature);

    verified.is_ok().encode(env)
}

rustler::init!(
    "Elixir.Hexpds.K256.Internal",
    [create_public_key, compress_public_key, sign_message, verify_signature]
);
