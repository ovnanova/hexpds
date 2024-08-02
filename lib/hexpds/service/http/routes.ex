defmodule Hexpds.Http.Routes do
  alias Hexpds.XRPC
  require XRPC

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

      _ ->
        {400, %{error: "InvalidRequest", message: "Unknown user."}}
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
    domain = Application.get_env(:hexpds, :pds_host)
    {200,
     %{
       # These will all change, obviously
       availableUserDomains: [domain],
       did: "did:web:#{domain}"
     }}
  end

  XRPC.query _, "com.atproto.sync.subscribeRepos", _params_for_backfilling_to_implement_at_some_point, _ do
    {200, {:websock, {Hexpds.Firehose.Websocket, [], timeout: :infinity}}}
  end

  @spec xrpc_procedure(Plug.Conn.t(), String.t(), map(), Hexpds.Auth.Context.t()) ::
          {integer(), map() | {:blob, Hexpds.Blob.t()}}

  XRPC.procedure _,
                 "com.atproto.server.createSession",
                 %{identifier: username, password: pw},
                 _ do
    {200, Hexpds.Auth.Session.new(username, pw)}
  end

  XRPC.procedure c, "com.atproto.server.refreshSession", _, ctx do
    XRPC.if_authed ctx, :refresh do
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
    XRPC.if_authed ctx do
      Hexpds.User.Preferences.put(ctx.user, prefs)
      {200, XRPC.blank()}
    end
  end

  XRPC.procedure _, "com.atproto.repo.uploadBlob", {:blob, blob_bytes}, ctx do
    XRPC.if_authed ctx do
      blob =
        Hexpds.Blob.new(blob_bytes, ctx.user)
        |> tap(&Hexpds.Blob.save/1)

      response = %{
        blob: %{
          "$type": "blob",
          ref: %{
            "$link": to_string(blob.cid)
          },
          mimeType: blob.mime_type,
          size: byte_size(blob.data)
        }
      }

      {200, response}
    end
  end

  XRPC.procedure _,
                 "com.atproto.repo.createRecord",
                 %{repo: did, collection: collection, record: record} = params,
                 ctx do
    XRPC.if_authed ctx do
      unless did == ctx.user.did do
        {401, %{error: "Unauthorized", message: "Not authorized"}}
      else
        {200,
         Hexpds.Repo.create_record(
           ctx.user,
           record,
           collection,
           params[:rkey] || "#{Hexpds.Tid.now()}"
         )}
      end
    end
  end
end
