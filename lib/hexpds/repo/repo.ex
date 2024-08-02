defmodule Hexpds.Repo do
  def create_record(
        %Hexpds.User{did: did} = user,
        %{"$type" => collection} = record,
        collection,
        rkey \\ "#{Hexpds.Tid.now()}"
      ) do
    Hexpds.User.Sqlite.exec(user, fn ->
      block = Hexpds.EctoBlockStore.put_block(record)

      record =
        %Hexpds.Repo.Record{
          record_cid: block.block_cid,
          collection: collection,
          record_path: "#{collection}/#{rkey}"
        }
        |> Hexpds.User.Sqlite.insert!()

        # Obviously MST and Commits stuff are missing here

        %{
          uri: "at://#{did}/#{record.record_path}",
          cid: record.record_cid
        }
    end)
  end
end
