defmodule Hipdster.Identity do
  @moduledoc """
  Stuff like resolving a handle, fetching a DID, generating JWTs, etc
  """

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

  def is_did?({:ok, "did:" <> _did} = arg), do: arg
  def is_did?({:ok, anything_else}), do: {:error, not_a_did: anything_else}

  defmacrop handle_errors(do: block) do
    quote do
      try do
        {:ok, unquote(block)}
      rescue
        error -> {:error, error}
      end
    end
  end

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
    do: "https://#{Application.get_env(:hipdster, :plc_server)}/#{did}"

  def did_url("did:web:" <> domain), do: "https://#{domain}/.well-known/did.json"

  def get_did(did) do
    with {:ok, %{body: body}} <-
           HTTPoison.get(did_url(did)) do
      {:ok, Jason.decode!(body)}
    end
  end
end
