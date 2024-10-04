defmodule Hexpds.Application do
  use Application

  @impl Application
  def start(_type, _args) do
    Hexpds.Database.Mnesia.create_tables()
    
    :syn.add_node_to_scopes([:firehose])
    
    children = [
      {Bandit, plug: Hexpds.Http, scheme: :http, port: Application.get_env(:hexpds, :port)},
      {Hexpds.Multicodec, Application.get_env(:hexpds, :multicodec_csv_path)},
      {Hexpds.Database, []},
      {Hexpds.Auth.Session.Cleaner, []},
      {Hexpds.Car.Writer.Process, file_path: "output.car"}
    ]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: Hexpds.Supervisor
    )
  end
end
