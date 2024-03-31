use rustler::Encoder;
use rustler::Env;
use rustler::NifResult;
use rustler::Term;
use rustler::Binary;
use serde_json::from_str;
use serde_json::Value;
use serde_json::json;
use libipld::Ipld;
use libipld::Cid;
use libipld::codec::Codec;
use libipld::cbor::DagCborCodec;
use std::collections::BTreeMap;
use std::str::FromStr;
use data_encoding::BASE64_NOPAD;


mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

// taken from bnewbold/adenosine (https://gitlab.com/bnewbold/adenosine)
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

// Taken from bnewbold/adenosine
pub fn ipld_to_json(val: Ipld) -> Value {
    match val {
        Ipld::Null => Value::Null,
        Ipld::Bool(b) => Value::Bool(b),
        Ipld::Integer(v) => json!(v),
        Ipld::Float(v) => json!(v),
        Ipld::String(s) => Value::String(s),
        Ipld::Bytes(b) => Value::String(BASE64_NOPAD.encode(&b)),
        Ipld::List(l) => Value::Array(l.into_iter().map(ipld_to_json).collect()),
        Ipld::Map(m) => Value::Object(serde_json::Map::from_iter(
            m.into_iter().map(|(k, v)| (k, ipld_to_json(v))),
        )),
        Ipld::Link(c) => Value::String(c.to_string()),
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

    let json_string = match serde_json::to_string(&json) {
        Ok(string) => string,
        Err(e) => return (atoms::error(), format!("Failed to serialize JSON: {}", e)).encode(env),
    };

    (atoms::ok(), json_string).encode(env)
}

rustler::init!("Elixir.Hipdster.DagCBOR.Internal", [encode_dag_cbor, decode_dag_cbor]);
