defmodule Hexpds.User.Sqlite do
  @moduledoc """
  Users' repos will be stored in individual sqlite DBs
  """

  use Ecto.Repo,
    otp_app: :hexpds,
    adapter: Ecto.Adapters.SQLite3

  def get_for_user(%Hexpds.User{did: did}) do
    repo_path = "repos/#{did}/repo.db"
    {:ok, db} = start_link(name: nil, database: repo_path)
    db
  end


  def migrate(migrations) do
    order_migrations =
      migrations
      |> Enum.with_index()
      |> Enum.map(fn {m, i} -> {i, m} end)
    Ecto.Migrator.run(__MODULE__, order_migrations, :up, all: true, dynamic_repo: get_dynamic_repo())
  end

  def exec(user, callback) do
    repo = get_for_user(user)
    try do
      put_dynamic_repo(repo)
      callback.()
    after
      Supervisor.stop(repo)
    end
  end
end
