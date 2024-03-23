defmodule Hipdster.Auth.PersistAuthDb do

  @moduledoc """
  Just saves the auth DB to disk every 20 seconds
  I know, this is very bad, I'm sorry.
  I will fix that soon, I promise
  """

  use Task
  def start_link(_) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    :timer.sleep(:timer.seconds(20))
    Hipdster.Auth.DB.persist()
    run()
  end

end
