defmodule Hipdster.Application do
  use Application

  @impl Application
  def start(_type, _args) do
    Hipdster.Multicodec.start_link()
  end
end
