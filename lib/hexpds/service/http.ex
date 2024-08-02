defmodule Hexpds.Http do
  @moduledoc """
  The XRPC interface to the PDS, including AppView proxying
  """
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  # plug(Plug.Parsers,
  #   parsers: [:json],
  #   pass: ["text/*"],
  #   json_decoder: Jason
  # )

  options "/xrpc/:any" do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET,HEAD,PUT,PATCH,POST,DELETE")
    |> put_resp_header(
      "access-control-allow-headers",
      "atproto-accept-labelers,authorization,content-type"
    )
    |> put_resp_header("access-control-max-age", "86400")
    |> put_resp_header("content-length", "0")
    |> send_resp(204, "")
  end

  get "/" do
    send_resp(conn, 200, """
    Hello from hexPDS
    ATProto PDS
    routes /xrpc/*

    Code on GitHub page
    find it at ovnanova
    slash hexpds
    """)
  end

  get "/favicon.ico" do
    send_resp(conn, 200, "Why would a PDS need a favicon?")
  end

  def respond_with(conn, {statuscode, resp_body}) do
    case resp_body do
      {:blob, blob} ->
        conn
        |> Plug.Conn.put_resp_content_type(blob.mime_type)
        |> Plug.Conn.send_resp(statuscode, blob.data)
        |> Plug.Conn.halt()
        |> IO.inspect()

      {:websock, {module, args, [timeout: timeout]}} ->
        conn
        |> WebSockAdapter.upgrade(module, args, timeout: timeout)
        |> halt()

      _ ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.put_resp_header("access-control-allow-origin", "*")
        |> Plug.Conn.send_resp(statuscode, Jason.encode!(resp_body))
    end
  end

  get "/ws/firehose_test" do
    conn
    |> WebSockAdapter.upgrade(Hexpds.Firehose.Websocket, [], timeout: 60_000)
    |> halt()
  end

  get "/.well-known/atproto-did" do
    {status, resp} =
      case Hexpds.User.get(conn.host) do
        %Hexpds.User{did: did} -> {200, did}
        _ -> {404, "User not found"}
      end

    send_resp(conn, status, resp)
  end

  get "/xrpc/:method" do
    conn = fetch_query_params(conn)

    # If you're using a non-known query param you deserve that exception, hence String.to_existing_atom/1
    # Ignore above comment. Have to use to_atom/1 because of appview proxying which involves inherently unknown routes
    params =
      for {key, val} <- conn.query_params, into: %{}, do: {String.to_atom(key), val}

    context = get_context(conn)

    resp =
      try do
        # We can handle the method
        IO.puts("Got query: #{method} #{inspect(params)}")

        Hexpds.Http.Routes.xrpc_query(conn, method, params, context)
        |> IO.inspect()
      catch
        _, e_from_method ->
          try do
            # We can't handle the method - try the appview
            case e_from_method do
              %FunctionClauseError{} -> IO.inspect(e_from_method)
              :function_clause -> IO.inspect(e_from_method)
              _ -> throw(e_from_method)
            end

            forward_query_to_appview(IO.inspect(appview_for(conn)), conn, method, params, context)
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

      respond_with(conn, resp)
  end

  post "/xrpc/:method" do
    {:ok, body, _} = Plug.Conn.read_body(conn)

    body =
      case Jason.decode(body) do
        {:ok, map} ->
          for {key, value} <- map, into: %{}, do: {String.to_atom(key), value}

        {:error, _} ->
          {:blob, body}
      end

    resp = Hexpds.Http.Routes.xrpc_procedure(conn, method, body, get_context(conn))

    respond_with(conn, resp)
  end

  defp appview_for(%Plug.Conn{req_headers: r_h}) do
    r_h
    |> Enum.into(%{})
    |> Map.get("atproto-proxy")
  end

  def url_of(nil), do: nil

  # Caching wouldn't be a bad idea
  def url_of(atproto_proxy) do
    with [did, service] <- String.split(atproto_proxy, "#"),
         label <- "##{service}",
         {:ok, did_doc} <- Hexpds.Identity.get_did(did),
         %{"service" => services} <- did_doc,
         %{"serviceEndpoint" => "https://" <> endpoint} <-
           services
           |> Enum.find(fn
             %{"id" => ^label} -> true
             _ -> false
           end) do
      endpoint
    else
      err -> raise "Bad atproto-proxy header: #{inspect(err)}"
    end
  end

  defp forward_query_to_appview(appview_did, _conn, method, params, context) do
    # Ignore auth for now

    headers =
      case context do
        %{authed: true, user: %{did: did}} ->
          [
            Authorization:
              "Bearer " <>
                Hexpds.Auth.JWT.interservice!(did, appview_did)
          ]

        _ ->
          []
      end

    %{status_code: statuscode, body: json_body} =
      ("https://" <>
         (url_of(appview_did) || Application.get_env(:hexpds, :appview_server)) <>
         "/xrpc/" <> method <> "?" <> URI.encode_query(params))
      |> HTTPoison.get!(headers)

    {statuscode, Jason.decode!(json_body)}
  end

  defp get_context(%Plug.Conn{req_headers: r_h}) do
    r_h
    |> Enum.into(%{})
    |> Map.get("authorization")
    |> Hexpds.Auth.Context.parse_header()
  end
end
