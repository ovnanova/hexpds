defmodule Hexpds.Database.Mnesia do
  # One can never have too many databases

  @moduledoc """
  Right now Mnesia is just used to maintain
  a cache of session jwts and their validity.
  """
  @tables [Hexpds.Auth.Session]

  def tables, do: @tables

  def create_tables do
    tables()
    |> Enum.map(&Memento.Table.create/1)
  end
end
