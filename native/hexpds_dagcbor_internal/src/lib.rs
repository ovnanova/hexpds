use rustler::Encoder;
use rustler::Env;
use rustler::NifResult;
use rustler::Term;
use rustler::Binary;
use serde_json::from_str;
use serde_json::Value;
use libipld::Ipld;
use libipld::Cid;
use libipld::codec::Codec;
use libipld::cbor::DagCborCodec;
use std::collections::BTreeMap;
use std::str::FromStr;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

pub fn json_to_ipld(val: Value) -> Ipld {
    match val {
        Value::Null => Ipld::Null,
        Value::Bool(b) => Ipld::Bool(b),
        Value::String(s) => Ipld::String(s),
        Value::Number(v) => {
            if let Some(f) = v.as_f64() {
                if v.is_i64() {
                    Ipld::Integer(v.as_i64().unwrap().into())
                } else if v.is_u64() {
                    Ipld::Integer(v.as_i64().unwrap_or_else(|| f as i64).into())
                } else {
                    Ipld::Float(f)
                }
            } else {
                Ipld::Null
            }
        },
        Value::Array(l) => Ipld::List(l.into_iter().map(json_to_ipld).collect()),
        Value::Object(m) => {
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

#[rustler::nif]
fn encode_dag_cbor(env: Env, json: String) -> NifResult<Term> {
    let parsed_json: serde_json::Value = match from_str(&json) {
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
        },
        Err(e) => {
            return Ok((atoms::error(), format!("Failed to encode to DAG-CBOR: {}", e)).encode(env));
        }
    }
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