defmodule Hexpds.Application do
  use Application

  @impl Application
  def start(_type, _args) do
    Hexpds.Database.Mnesia.create_tables()

    Supervisor.start_link(
      [
        {Bandit, plug: Hexpds.Http, scheme: :http, port: Application.get_env(:hexpds, :port)},
        {Hexpds.Multicodec, Application.get_env(:hexpds, :multicodec_csv_path)},
        {Hexpds.Database, []},
        {Hexpds.Auth.Session.Cleaner, []}
      ],
      strategy: :one_for_one,
      name: Hexpds.Supervisor
    )
  end
end
