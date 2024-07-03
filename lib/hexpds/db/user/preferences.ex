defmodule Hexpds.User.Preferences do
  @moduledoc """
  A user's preferences
  """

  import Ecto.Changeset

  def put(%Hexpds.User{} = user, %{} = params) do
    user
    |> change(%{data: %{"preferences" => params}})
    |> Hexpds.Database.update()
  end
end
