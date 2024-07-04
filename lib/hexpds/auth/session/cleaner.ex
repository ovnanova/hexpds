defmodule Hexpds.Auth.Session.Cleaner do
  @moduledoc """
  Deletes expired sessions on the hour
  """

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    :timer.send_interval(3_600_000, :clean)
    {:ok, nil}
  end

  @impl GenServer
  def handle_info(:clean, state) do
    Memento.transaction!(fn ->
      :mnesia.foldl(
        fn {_, r_jwt, _, _}, _ ->
          unless is_map(Hexpds.Auth.JWT.verify(r_jwt)) do
            Hexpds.Auth.Session.delete(r_jwt)
          end
        end,
        nil,
        Hexpds.Auth.Session
      )
    end)

    {:noreply, state}
  end
end
