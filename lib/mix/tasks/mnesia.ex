defmodule Mix.Tasks.Mnesia.Setup do
  use Mix.Task

  @nodes [node()]

  @impl Mix.Task
  def run(_) do
    # Create the DB directory (if custom path given)
    if path = Application.get_env(:mnesia, :dir) do
      :ok = File.mkdir_p!(path)
    end

    # Create the Schema
    Memento.stop()
    Memento.Schema.create(@nodes)
    Memento.start()


    Enum.each(Hipdster.Database.Mnesia.tables(), &Memento.Table.create(&1, disc_copies: @nodes))
  end
end
