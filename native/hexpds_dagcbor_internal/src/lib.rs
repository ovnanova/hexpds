use rustler::Encoder;
use rustler::Env;
use rustler::Term;
use rustler::Binary;
use serde_json::from_str;
use serde_ipld_dagcbor::to_vec;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn encode_dag_cbor(env: Env, json: String) -> Term {
        let parsed_json: serde_json::Value = match from_str(&json) {
            Ok(json) => json,
            Err(e) => return (atoms::error(), format!("Failed to parse JSON: {}", e)).encode(env),
        };

    let cbor_data = match to_vec(&parsed_json) {
        Ok(data) => data,
        Err(e) => return (atoms::error(), format!("Failed to encode to DAG-CBOR: {}", e)).encode(env),
    };

    (atoms::ok(), cbor_data).encode(env)
}

#[rustler::nif]
fn decode_dag_cbor<'a>(env: Env<'a>, cbor_data: Binary<'a>) -> Term<'a> {
    let parsed_cbor: serde_json::Value = match serde_ipld_dagcbor::from_slice(&cbor_data) {
        Ok(cbor) => cbor,
        Err(e) => return (atoms::error(), format!("Failed to parse DAG-CBOR: {}", e)).encode(env),
    };

    let json = match serde_json::to_string(&parsed_cbor) {
        Ok(json) => json,
        Err(e) => return (atoms::error(), format!("Failed to encode to JSON: {}", e)).encode(env),
    };

    (atoms::ok(), json).encode(env)
}

rustler::init!("Elixir.Hexpds.DagCBOR.Internal", [encode_dag_cbor, decode_dag_cbor]);
