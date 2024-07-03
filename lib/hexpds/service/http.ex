defmodule Hexpds.Http do
  @moduledoc """
  The XRPC interface to the PDS, including AppView proxying
  """
  alias Hexpds.XRPC
  require XRPC

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["text/*"],
    json_decoder: Jason
  )

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

    {statuscode, json_body} =
      try do
        # We can handle the method
        IO.puts("Got query: #{method} #{inspect(params)}")

        xrpc_query(conn, method, params, context)
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

    case json_body do
      {:blob, blob} ->
        conn
        |> Plug.Conn.put_resp_content_type(blob.mime_type)
        |> Plug.Conn.send_resp(200, blob.data)
        |> Plug.Conn.halt()
        |> IO.inspect()

      _ ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.put_resp_header("access-control-allow-origin", "*")
        |> Plug.Conn.send_resp(statuscode, Jason.encode!(json_body))
    end
  end

  post "/xrpc/:method" do
    {:ok, body, _} = Plug.Conn.read_body(conn)

    body =
      for {key, val} <- Jason.decode!(body), into: %{}, do: {String.to_atom(key), val}

    {statuscode, json_resp} = xrpc_procedure(conn, method, body, get_context(conn))

    case json_resp do
      {:blob, blob} ->
        conn
        |> Plug.Conn.put_resp_content_type(blob.mime_type)
        |> Plug.Conn.send_resp(200, blob.data)

      _ ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.put_resp_header("access-control-allow-origin", "*")
        |> Plug.Conn.send_resp(statuscode, Jason.encode!(json_resp))
    end
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

  @spec xrpc_query(Plug.Conn.t(), String.t(), map(), Hexpds.Auth.Context.t()) ::
          {integer(), map() | {:blob, Hexpds.Blob.t()}}

  XRPC.query _, "app.bsky.actor.getPreferences", %{}, ctx do
    case ctx do
      %{user: %Hexpds.User{} = user, token_type: :access} ->
        {200, %{preferences: user.data["preferences"]}}

      _ ->
        {401, %{error: "Unauthorized", message: "Not authorized"}}
    end
  end

  XRPC.query _, "com.atproto.sync.getBlob", %{did: did, cid: cid}, _ do
    with %Hexpds.Blob{} = blob <- Hexpds.Blob.get(cid, did) do
      {200, {:blob, blob}}
    else
      _ -> {400, %{error: "InvalidRequest", message: "No such blob"}}
    end
  end

  XRPC.query _, "com.atproto.sync.listBlobs", opts, _ do
    case Hexpds.Xrpc.Query.ListBlobs.list_blobs(
           opts[:did],
           opts[:since],
           String.to_integer(opts[:limit] || 500),
           Hexpds.CID.decode_cid!(opts[:cursor])
         ) do
      %{cids: cids, cursor: next_cursor} ->
        {200, %{cursor: next_cursor, cids: Enum.map(cids, &to_string/1)}}

      other ->
        {400, %{error: "InvalidRequest", message: inspect(other)}}
    end
  end

  XRPC.query _, "com.atproto.server.getSession", %{}, ctx do
    case ctx do
      %{user: %Hexpds.User{did: did, handle: handle}, token_type: :access} ->
        {200, %{handle: handle, did: did}}

      _ ->
        {401, %{error: "Unauthorized", message: "Not authorized"}}
    end
  end

  XRPC.query _, "com.atproto.server.describeServer", _, _ do
    IO.puts("Describing server...")

    {200,
     %{
       # These will all change, obviously
       availableUserDomains: ["localhost"],
       did: "did:web:localhost"
     }}
  end

  @spec xrpc_procedure(Plug.Conn.t(), String.t(), map(), Hexpds.Auth.Context.t()) ::
          {integer(), map()}

  XRPC.procedure _,
                 "com.atproto.server.createSession",
                 %{identifier: username, password: pw},
                 _ do
    {200, Hexpds.Auth.Session.new(username, pw)}
  end

  XRPC.procedure c, "com.atproto.server.refreshSession", _, ctx do
    case ctx do
      %{user: %Hexpds.User{}, token_type: :refresh} ->
        c.req_headers
        |> Enum.into(%{})
        |> Map.get("authorization")
        |> case do
          "Bearer " <> token ->
            case Hexpds.Auth.Session.refresh(token) do
              %{} = session -> {200, session}
              _ -> {400, %{error: "InvalidToken", message: "Refresh session failed"}}
            end

          _ ->
            {400, %{error: "InvalidToken", message: "Refresh session failed"}}
        end

      _ ->
        {401, %{error: "Unauthorized", message: "Not authorized"}}
    end
  end

  XRPC.procedure conn, "com.atproto.server.deleteSession", _, _ do
    conn.req_headers
    |> Enum.into(%{})
    |> Map.get("authorization")
    |> case do
      "Bearer " <> token ->
        case Hexpds.Auth.Session.delete(token) do
          :ok -> {200, %{}}
          _ -> {401, %{error: "InvalidToken", message: "Delete session failed"}}
        end

      _ ->
        {401, %{error: "InvalidToken", message: "Delete session failed"}}
    end
  end

  XRPC.procedure _, "app.bsky.actor.putPreferences", %{preferences: prefs}, ctx do
    case ctx do
      %{user: %Hexpds.User{} = user, token_type: :access} ->
        Hexpds.User.Preferences.put(user, prefs)
        {200, {:blob, %{mime_type: "application/octet-stream", data: ""}}}

      _ ->
        {401, %{error: "Unauthorized", message: "Not authorized"}}
    end
  end
end
