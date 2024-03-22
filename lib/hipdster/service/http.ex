defmodule Hipdster.Http do
  @moduledoc """
  The XRPC interface to the PDS, including AppView proxying
  """
  alias Hipdster.XRPC
  require XRPC

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "Hello from Hipdster!")
  end

  get "/favicon.ico" do
    send_resp(conn, 200, "Why would a PDS need a favicon?")
  end

  get "/xrpc/:method" do
    conn = conn |> Plug.Conn.fetch_query_params()
    params = for {key, val} <- conn.query_params, into: %{}, do: {String.to_atom(key), val}

    {statuscode, json_body} =
      try do
        # We can handle the method
        xrpc_query(conn, method, params)
      catch
        _, _e ->
          try do
            # We can't handle the method - try the appview
            appview_forward_get(get_appview(conn), conn, method, params)
          catch
            _, e ->
              IO.inspect(e, label: "AppView proxying error")

              {500,
               %{
                 error: "Error",
                 message: "Oh no! Bad request or internal server error",
                 debug: inspect(e)
               }}
          end
      end

    send_resp(conn, statuscode, Jason.encode!(json_body))
  end

  defp get_appview(conn) do
    conn.req_headers
    |> Enum.into(%{})
    |> Map.get("atproto_proxy", Application.get_env(:hipdster, :appview_server))
  end

  defp appview_forward_get(appview, _conn, method, params) do
    # Ignore auth for now
    %{status_code: statuscode, body: json_body} =
      "https://" <> appview <> "/xrpc/" <> method <> "?" <> URI.encode_query(params)
      |> HTTPoison.get!()

    {statuscode, Jason.decode!(json_body)}
  end

  # Don't bother with this for now
  XRPC.query _, "app.bsky.actor.getPreferences", %{} do
    {200, %{preferences: %{}}}
  end

  # Just because we can, let's resolve handles ourselves without any validation
  # Maybe a bad idea, and probably slightly slower than using the appview,
  # but... just as a test for now
  XRPC.query _, "com.atproto.identity.resolveHandle", %{handle: handle} do
    with {:ok, did} <- Hipdster.Identity.resolve_handle(handle) do
      {200, %{did: did}}
    end
  end
end
