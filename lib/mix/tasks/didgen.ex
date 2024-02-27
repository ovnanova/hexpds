defmodule Mix.Tasks.DidPlc.Generate do
  @moduledoc """
  Mix task to generate a DID:PLC: and publish it to the PLC server set in config/config.exs
  and prints its information (save it somewhere)!
  In the future this should save to a database.
  """

  use Mix.Task
  alias Hexpds.DidGenerator

  Application.ensure_all_started(:hexpds)

  @shortdoc "Generate a DID:PLC: and publish it to the PLC server set in config/config.exs - pass in a handle"
  @impl Mix.Task
  def run([handle | _]) do
    handle
    |> DidGenerator.generate_did()
    |> inspect(pretty: true)
    |> IO.puts()
  end
end
