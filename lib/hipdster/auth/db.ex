defmodule Hipdster.Auth.DB do
  @moduledoc """
  Wrappers around some common Mnesia functions
  """

  @tables [Hipdster.Auth.User]

  def create_tables do
    @tables
    |> Enum.map(&Memento.Table.create/1)
  end

  @spec create_user(Hipdster.Auth.User.t()) :: {:ok, Hipdster.Auth.User.t()}
  def create_user(%Hipdster.Auth.User{} = user) do
    Memento.transaction(fn -> Memento.Query.write(user) end)
  end

  @spec get_user(String.t()) :: Hipdster.Auth.User.t() | :error
  def get_user("did:" <> _ = did) do
    with {:ok, %Hipdster.Auth.User{} = user} <-
           Memento.transaction(fn -> Memento.Query.read(Hipdster.Auth.User, did) end) do
      user
    else
      _ -> :error
    end
  end

  def get_user(handle) do
    with {:ok, [user_tup]} <-
           Memento.transaction(fn -> :mnesia.index_read(Hipdster.Auth.User, handle, :handle) end) do
      Memento.Query.Data.load(user_tup)
    else
      _ -> :error
    end
  end
end
