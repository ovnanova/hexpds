defmodule Hexpds.Application do
  use Application

  @impl Application
  def start(_type, _args) do
    Hexpds.Multicodec.start_link()
  end
end
