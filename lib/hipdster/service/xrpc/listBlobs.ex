defmodule Hipdster.Xrpc.Query.ListBlobs do
  import Ecto.Query

  @spec ecto_query_for(String.t(), String.t()) :: Ecto.Query.t()
  def ecto_query_for(did, tid) do
    after_timestamp =
      Hipdster.Tid.from_string(tid).timestamp
      |> DateTime.from_unix!(:microsecond)

    from b in Hipdster.Blob,
      where: b.did == ^did,
      where: b.inserted_at > ^after_timestamp,
      order_by: [desc: b.inserted_at, desc: b.id],
      select: b.cid
  end

  def list_blobs(did, tid \\ nil, limit \\ nil, cursor \\ nil) do
    query = ecto_query_for(did, tid || "#{Hipdster.Tid.empty()}")

    cids =
      if cursor do
        last =
          Hipdster.Blob
          |> where(cid: ^cursor)
          |> Hipdster.Database.one()

        from b in query, where: b.inserted_at < ^last.inserted_at, limit: ^limit
      else
        from b in query, limit: ^limit
      end
      |> Hipdster.Database.all()

    %{
      cids: cids,
      cursor: to_string(List.last(cids))
    }
  end
end
