defmodule Hexpds.DidGenerator do
  require Logger
  alias Hexpds.K256, as: K256

  @spec genesis_to_did(map()) :: String.t()
  def genesis_to_did(%{"type" => "plc_operation", "prev" => nil} = signed_genesis) do
    "did:plc:" <>
      with {:ok, signed_genesis_json} <-
             signed_genesis
             |> Jason.encode(),
           {:ok, signed_genesis_cbor} <-
             signed_genesis_json
             |> Hexpds.DagCBOR.encode(),
           do:
             :crypto.hash(:sha256, signed_genesis_cbor)
             |> Base.encode32(case: :lower)
             |> String.slice(0..23)
             |> String.downcase()
  end

  @spec publish_to_plc(map(), String.t()) ::
          {:error,
           %{
             :__exception__ => true,
             :__struct__ => Jason.EncodeError | Protocol.UndefinedError,
             optional(atom()) => any()
           }}
          | %{
              :__struct__ =>
                HTTPoison.AsyncResponse | HTTPoison.MaybeRedirect | HTTPoison.Response,
              optional(:body) => any(),
              optional(:headers) => list(),
              optional(:id) => reference(),
              optional(:redirect_url) => any(),
              optional(:request) => HTTPoison.Request.t(),
              optional(:request_url) => any(),
              optional(:status_code) => integer()
            }
  def publish_to_plc(
        %{"type" => "plc_operation", "prev" => nil} = signed_genesis,
        "https://" <> plc_url
      ) do
    did = genesis_to_did(signed_genesis)
    Logger.info("DID is #{did}")

    with {:ok, json} <- Jason.encode(signed_genesis) do
      Logger.info("JSON: #{json}")
      Logger.info("Publishing to https://#{plc_url}/#{did}")

      HTTPoison.post!("https://" <> plc_url <> "/#{did}", json,
        "Content-Type": "application/json"
      )
    end
  end

  def generate_did(
        "" <> handle,
        "" <> plc_dir_url \\ "https://#{Application.get_env(:hexpds, :plc_server)}",
        "" <> pds_url \\ Application.get_env(:hexpds, :pds_host)
      ) do
    rotation_key = K256.PrivateKey.create()
    signing_key = K256.PrivateKey.create()
    Logger.info("Rotation key: #{rotation_key |> K256.PrivateKey.to_hex()}")
    Logger.info("Signing key: #{signing_key |> K256.PrivateKey.to_hex()}")

    genesis =
      Hexpds.DidPlc.Operation.genesis(
        rotation_key,
        signing_key,
        handle,
        pds_url
      )

    signed_genesis = Hexpds.DidPlc.Operation.add_sig(genesis, rotation_key)
    did = genesis_to_did(signed_genesis)
    Logger.info("DID: #{did}")

    %{
      did: did,
      genesis: signed_genesis,
      rotation_key: rotation_key |> K256.PrivateKey.to_hex(),
      signing_key: signing_key |> K256.PrivateKey.to_hex(),
      handle: handle,
      response: publish_to_plc(signed_genesis, plc_dir_url)
    }
  end
end
