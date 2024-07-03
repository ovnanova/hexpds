defmodule Hexpds.Xrpc.Query.ListBlobs do
  import Ecto.Query

  @spec ecto_query_for(String.t(), String.t()) :: Ecto.Query.t()
  def ecto_query_for(did, tid) do
    after_timestamp =
      Hexpds.Tid.from_string(tid).timestamp
      |> DateTime.from_unix!(:microsecond)

    from b in Hexpds.Blob,
      where: b.did == ^did,
      where: b.inserted_at > ^after_timestamp,
      order_by: [desc: b.inserted_at, desc: b.id],
      select: b.cid
  end

  def list_blobs(did, tid \\ nil, limit \\ nil, cursor \\ nil) do
    query = ecto_query_for(did, tid || "#{Hexpds.Tid.empty()}")

    cids =
      if cursor do
        last =
          Hexpds.Blob
          |> where(cid: ^cursor)
          |> Hexpds.Database.one()

        from b in query, where: b.inserted_at < ^last.inserted_at, limit: ^limit
      else
        from b in query, limit: ^limit
      end
      |> Hexpds.Database.all()

    %{
      cids: cids,
      cursor: to_string(List.last(cids))
    }
  end
end
