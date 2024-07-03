defmodule Hexpds.Identity do
  @moduledoc """
  Stuff like resolving a handle, fetching a DID, generating JWTs, etc
  """

  import Hexpds.Helpers

  @typedoc """
  A string representing a DID in the format `did:plc:<hex>`
  """
  @type did_plc :: <<_::256>>
  @typedoc """
  A string representing a DID in the format `did:web:<domain>`
  """
  @type did_web :: String.t()

  @typedoc """
  A DID as a string
  """
  @type did :: did_plc() | did_web()

  @typedoc """
  A handle as a string
  """
  @type handle :: String.t()

  @spec resolve_handle(String.t()) :: {:ok, did()} | {:error, any()}
  def resolve_handle(domain) do
    lookup_did_by_dns(domain)
    |> case do
      {:ok, did} ->
        is_did?({:ok, did})

      {:error, dns_error} ->
        get_did_from_http(domain)
        |> case do
          {:ok, did} -> is_did?({:ok, did})
          {:error, http_error} -> {:error, dns_error: dns_error, http_error: http_error}
        end
    end
  end

  @spec is_did?({:ok, did()}) :: {:ok, did()}
  def is_did?({:ok, "did:" <> _did} = arg), do: arg
  @spec is_did?({:ok, any()}) :: {:error, not_a_did: any()}
  def is_did?({:ok, anything_else}), do: {:error, not_a_did: anything_else}

  defp lookup_did_by_dns(domain) do
    handle_errors do
      [[did_record]] = :inet_res.lookup(~c"_atproto.#{domain}", :in, :txt)
      "did=" <> did = to_string(did_record)
      did
    end
  end

  defp get_did_from_http(domain) do
    handle_errors do
      HTTPoison.get!("https://#{domain}/.well-known/atproto-did").body
    end
  end

  def did_url("did:plc:" <> _did = did),
    do: "https://#{Application.get_env(:hexpds, :plc_server)}/#{did}"

  def did_url("did:web:" <> domain), do: "https://#{domain}/.well-known/did.json"

  def get_did(did) do
    with {:ok, %{body: body}} <-
           HTTPoison.get(did_url(did)) do
      {:ok, Jason.decode!(body)}
    end
  end
end
