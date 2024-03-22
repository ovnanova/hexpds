defmodule Hipdster.Application do
  alias Hipdster.Multicodec
  use Application

  @impl Application
  def start(_type, _args) do
    Multicodec.start_link()
    Supervisor.start_link(
      [
        {Bandit, plug: Hipdster.Http, scheme: :http},
      ],
      strategy: :one_for_one,
      name: Hipdster.Supervisor
    )
  end
end
