defmodule Hexpds.Firehose.Websocket do
  @behaviour WebSock

  @impl WebSock
  def init(_params) do
    # We can ignore the params for now but we should use them for backfilling later
    pid = self()
    :syn.join(:firehose, :websockets, pid)
    {:ok, nil}
  end

  @impl WebSock
  def handle_info({:firehose_message, bindata}, _) do
    {:push, {:binary, bindata}, nil}
  end

  @impl WebSock
  def handle_in(_, _) do
    # Ignore incoming messages
    {:ok, nil}
  end

  def push_frame(frame) do
    :syn.publish(:firehose, :websockets, {:firehose_message, frame})
  end
end
