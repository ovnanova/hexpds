use jwt_simple::prelude::*;
use rustler::{Env, Term};
use std::time::{SystemTime, UNIX_EPOCH};

#[rustler::nif]
fn generate_jwt(
    account_did: String,
    service_did: String,
    key: &[u8],
    is_k256: bool,
) -> Result<String, &'static str> {
    let key = if is_k256 {
        ES256KKeyPair::from_bytes(key).map_err(|_| "Invalid K256 key")?
    } else {
        ES256KeyPair::from_bytes(key).map_err(|_| "Invalid P256 key")?
    };

    let mut claims = Claims::create(Duration::from_secs(60));
    claims.issuer = Some(account_did);
    claims.audience = Some(vec![service_did]);
    claims.issued_at = Some(
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs()
            .into(),
    );

    let token = if is_k256 {
        key.sign(claims).map_err(|_| "Signing failed")?
    } else {
        key.sign(claims).map_err(|_| "Signing failed")?
    };

    Ok(token)
}

fn load(env: Env, _info: Term) -> bool {
    rustler::resource!(MyResource, env);
    true
}

rustler::init!(
    "Elixir.Hipdster.Auth.JWT.Internal",
    [generate_jwt],
    load = load
);
