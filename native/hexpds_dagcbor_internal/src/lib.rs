use data_encoding::BASE64_NOPAD;
use libipld::cbor::DagCborCodec;
use libipld::codec::Codec;
use libipld::Cid;
use libipld::Ipld;
use rustler::Binary;
use rustler::Encoder;
use rustler::Env;
use rustler::NifResult;
use rustler::Term;
use serde_json::json;
use serde_json::Value as JsonValue;
use std::collections::BTreeMap;
use std::str::FromStr;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

// taken from bnewbold/adenosine (https://gitlab.com/bnewbold/adenosine)
pub fn json_to_ipld(val: JsonValue) -> Ipld {
    match val {
        JsonValue::Null => Ipld::Null,
        JsonValue::Bool(b) => Ipld::Bool(b),
        JsonValue::String(s) => Ipld::String(s),
        JsonValue::Number(v) => {
            if let Some(f) = v.as_f64() {
                if v.is_i64() {
                    Ipld::Integer(v.as_i64().unwrap().into())
                } else if v.is_u64() {
                    Ipld::Integer(v.as_i64().unwrap_or(f as i64).into())
                } else {
                    Ipld::Float(f)
                }
            } else {
                Ipld::Null
            }
        }
        JsonValue::Array(l) => Ipld::List(l.into_iter().map(json_to_ipld).collect()),
        JsonValue::Object(m) => {
            let map: BTreeMap<String, Ipld> = BTreeMap::from_iter(m.into_iter().map(|(k, v)| {
                if k == "cid" && v.is_string() {
                    (k, Ipld::Link(Cid::from_str(v.as_str().unwrap()).unwrap()))
                } else {
                    (k, json_to_ipld(v))
                }
            }));
            Ipld::Map(map)
        }
    }
}

// Taken from bnewbold/adenosine
pub fn ipld_to_json(val: Ipld) -> JsonValue {
    match val {
        Ipld::Null => JsonValue::Null,
        Ipld::Bool(b) => JsonValue::Bool(b),
        Ipld::Integer(v) => json!(v),
        Ipld::Float(v) => json!(v),
        Ipld::String(s) => JsonValue::String(s),
        Ipld::Bytes(b) => JsonValue::String(BASE64_NOPAD.encode(&b)),
        Ipld::List(l) => JsonValue::Array(l.into_iter().map(ipld_to_json).collect()),
        Ipld::Map(m) => JsonValue::Object(serde_json::Map::from_iter(
            m.into_iter().map(|(k, v)| (k, ipld_to_json(v))),
        )),
        Ipld::Link(c) => JsonValue::String(c.to_string()),
    }
}

#[rustler::nif]
fn encode_dag_cbor(env: Env, json: String) -> NifResult<Term> {
    let parsed_json: JsonValue = match serde_json::from_str(&json) {
        Ok(json) => json,
        Err(e) => return Ok((atoms::error(), format!("Failed to parse JSON: {}", e)).encode(env)),
    };

    let ipld_data = json_to_ipld(parsed_json);

    let encoded_dag_cbor = DagCborCodec.encode(&ipld_data);

    match encoded_dag_cbor {
        Ok(buffer) => {
            let mut binary = rustler::types::binary::OwnedBinary::new(buffer.len()).unwrap();

            {
                let binary_slice = binary.as_mut_slice();
                binary_slice.copy_from_slice(&buffer);
            }

            Ok((atoms::ok(), binary.release(env)).encode(env))
        }
        Err(e) => {
            return Ok((
                atoms::error(),
                format!("Failed to encode to DAG-CBOR: {}", e),
            )
                .encode(env));
        }
    }
}

#[rustler::nif]
fn decode_dag_cbor<'a>(env: Env<'a>, cbor_data: Binary<'a>) -> Term<'a> {
    let decoded_cbor = match DagCborCodec.decode(&cbor_data) {
        Ok(cbor) => cbor,
        Err(e) => {
            return (
                atoms::error(),
                format!("Failed to decode from DAG-CBOR: {}", e),
            )
                .encode(env)
        }
    };

    let json = ipld_to_json(decoded_cbor);

    match serde_json::to_string(&json) {
        Ok(string) => (atoms::ok(), string).encode(env),
        Err(e) => return (atoms::error(), format!("Failed to serialize JSON: {}", e)).encode(env),
    }
}

rustler::init!(
    "Elixir.Hexpds.DagCBOR.Internal",
    [encode_dag_cbor, decode_dag_cbor]
);
