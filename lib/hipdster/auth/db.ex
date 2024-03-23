defmodule Hipdster.Auth.DB do
  @moduledoc """
  This is a very temporary implementation that does some very stupid stuff.
  It'll probably be replaced by a central Postgres database that also
  handles firehose stuff
  """

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    case load() do
      {:ok, table} ->
        {:ok, table}

      {:error, _} ->
        {:ok, :ets.new(__MODULE__, [:set, :public])}
    end
  end

  @impl GenServer
  def handle_call(:get_table, _, state) do
    {:reply, state, state}
  end

  @spec table() :: :ets.tab()
  def table() do
    GenServer.call(__MODULE__, :get_table)
  end

  def persist do
    :ets.tab2file(table(), ~c"auth.ets")
  end

  defp load do
    :ets.file2tab(~c"auth.ets")
  end

  @spec create_user(Hipdster.Auth.User.t()) :: true
  def create_user(%Hipdster.Auth.User{did: did} = user) do
    :ets.insert(table(), {did, user})
    |> tap(fn _ -> persist() end)
  end

  @spec get_user(String.t()) :: Hipdster.Auth.User.t() | :error
  def get_user("did:" <> _ = did) do
      :ets.lookup_element(table(), did, 2, :error)
  end

  def get_user(handle) do
    with {:halt, u} <-
           :ets.foldl(
             fn
               {_did, %Hipdster.Auth.User{handle: ^handle} = user}, _acc ->
                 {:halt, user}

               _, acc ->
                 acc
             end,
             :error,
             table()
           ),
         do: u
  end
end
