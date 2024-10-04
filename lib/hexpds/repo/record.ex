defmodule Hexpds.Repo.Record do
  use Ecto.Schema
  import Ecto.Query

  # Again, this belongs in Hexpds.User.Sqlite

  schema "records" do
    field :record_path, :string
    field :collection, :string
    field :record_cid, :string
    timestamps()
  end

  def all_in_collection(collection) do
    from r in __MODULE__, where: r.collection == ^collection, order_by: r.inserted_at
  end

end
