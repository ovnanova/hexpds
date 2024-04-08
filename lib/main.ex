defmodule Hipdster.Application do
  use Application

  @impl Application
  def start(_type, _args) do
    Supervisor.start_link(
      [
        {Bandit, plug: Hipdster.Http, scheme: :http},
        {Hipdster.Multicodec, Application.get_env(:hipdster, :multicodec_csv_path)},
        {Hipdster.Database, []}
      ],
      strategy: :one_for_one,
      name: Hipdster.Supervisor
    )
  end
end
