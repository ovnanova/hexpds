defmodule Hipdster.User.Preferences do
  @moduledoc """
  A user's preferences
  """

  import Ecto.Changeset

  def put(%Hipdster.User{} = user, %{} = params) do
    user
    |> change(%{data: %{"preferences" => params}})
    |> Hipdster.Database.update()
  end
end
