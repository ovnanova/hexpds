use jwt_simple::prelude::*;
use rustler::{Binary, Encoder, Env, Term};
use std::str;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn generate_k256_jwt<'a>(
    env: Env<'a>,
    account_did: Binary<'a>,
    service_did: Binary<'a>,
    subject: Binary<'a>,
    private_key: Binary<'a>,
) -> Term<'a> {
    let signing_key = match ES256kKeyPair::from_bytes(&private_key) {
        Ok(key) => key,
        Err(e) => {
            return (
                atoms::error(),
                format!("Failed to create secret key: {}", e),
            )
                .encode(env)
        }
    };

    let service_did_string = str::from_utf8(service_did.as_slice()).unwrap();
    let account_did = str::from_utf8(account_did.as_slice()).unwrap();

    let subject = str::from_utf8(subject.as_slice()).unwrap();

    let claim = Claims::create(Duration::from_mins(1))
        .with_issuer(account_did)
        .with_audience(service_did_string);

    let claim = match subject {
        "" => claim,
        s => claim.with_subject(s),
    };
    let token = match signing_key.sign(claim) {
        Ok(token) => token,
        Err(e) => return (atoms::error(), format!("Failed to sign token: {}", e)).encode(env),
    };

    let token = token.as_str();
    (atoms::ok(), token).encode(env)
}


#[rustler::nif]
fn generate_hs256_jwt<'a>(
    env: Env<'a>,
    account_did: Binary<'a>,
    subject: Binary<'a>,
    hs256_secret: Binary<'a>,
    time_in_minutes: i64,
) -> Term<'a> {
    let signing_key = HS256Key::from_bytes(&hs256_secret);

    let account_did = str::from_utf8(account_did.as_slice()).unwrap();
    let subject = str::from_utf8(subject.as_slice()).unwrap();

    let claim = Claims::create(Duration::from_mins(time_in_minutes as u64))
        .with_issuer(account_did)
        .with_subject(subject);

    let token = match signing_key.authenticate(claim) {
        Ok(token) => token,
        Err(e) => return (atoms::error(), format!("Failed to sign token: {}", e)).encode(env),
    };

    let token = token.as_str();
    (atoms::ok(), token).encode(env)
}

#[rustler::nif]
fn verify_hs256_jwt<'a>(env: Env<'a>, jwt: Binary<'a>, hs256_secret: Binary<'a>) -> Term<'a> {
    let signing_key = HS256Key::from_bytes(&hs256_secret);

    match signing_key.verify_token::<NoCustomClaims>(str::from_utf8(jwt.as_slice()).unwrap(), None) {
        Ok(token) => (atoms::ok(), token.serialize(serde_json::value::Serializer).unwrap().to_string()),
        Err(e) => (atoms::error(), format!("Failed to verify token: {}", e)),
    }.encode(env)
}


rustler::init!("Elixir.Hipdster.Auth.JWT.Internal", [generate_k256_jwt, generate_hs256_jwt, verify_hs256_jwt]);
