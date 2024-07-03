defmodule Hipdster.Application do
  use Application

  @impl Application
  def start(_type, _args) do
    Hipdster.Database.Mnesia.create_tables()
    Supervisor.start_link(
      [
        {Bandit, plug: Hipdster.Http, scheme: :http, port: Application.get_env(:hipdster, :port)},
        {Hipdster.Multicodec, Application.get_env(:hipdster, :multicodec_csv_path)},
        {Hipdster.Database, []},
        {Hipdster.Auth.Session.Cleaner, []}
      ],
      strategy: :one_for_one,
      name: Hipdster.Supervisor
    )
  end
end
