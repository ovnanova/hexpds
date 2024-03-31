defmodule Mix.Tasks.Database.Setup do
  use Mix.Task

  @nodes [node()]
  @tables [Hipdster.Auth.User]

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


    Enum.each(@tables, &Memento.Table.create!(&1, disc_copies: @nodes))

  end
end
