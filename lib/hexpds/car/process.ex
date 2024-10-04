defmodule Hexpds.Car.Writer.Process do
  @moduledoc """
  GenServer process responsible for managing the CAR stream.
  """

  use GenServer

  alias Hexpds.CID

  @doc """
  Starts the CAR writer GenServer.

  ## Options

    - `:file_path` - The path to the CAR file to write to.

  ## Examples

      iex> {:ok, pid} = Hexpds.Car.Writer.Process.start_link(file_path: "output.car")
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Adds a block to the CAR stream.

  ## Parameters

    - `cid`: The CID of the data block.
    - `serialized_entries`: The binary data to write.

  ## Returns

    - `:ok` on success.
    - `{:error, reason}` on failure.

  ## Examples

      iex> Hexpds.Car.Writer.Process.put(pid, cid, serialized_data)
      :ok
  """
  @spec put(pid(), CID.t(), binary()) :: :ok | {:error, term()}
  def put(pid, %CID{} = cid, serialized_entries) when is_binary(serialized_entries) do
    GenServer.call(pid, {:put, cid, serialized_entries})
  end

  @doc """
  Finalizes the CAR stream

  ## Parameters

    - `pid`: The PID of the CAR writer GenServer.

  ## Returns

    - `:ok` on success.
    - `{:error, reason}` on failure.

  ## Examples

      iex> Hexpds.Car.Writer.Process.finalize(pid)
      :ok
  """
  @spec finalize(pid()) :: :ok | {:error, term()}
  def finalize(pid) do
    GenServer.call(pid, :finalize)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    file_path = Keyword.fetch!(opts, :file_path)

    case File.open(file_path, [:write, :binary]) do
      {:ok, file} ->
        {:ok, %{file: file}}

      {:error, reason} ->
        {:stop, {:cannot_open_file, reason}}
    end
  end

  @impl true
  def handle_call({:put, cid, serialized_entries}, _from, state) do
    case write_block(state.file, cid, serialized_entries) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:finalize, _from, state) do
    case File.close(state.file) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    File.close(state.file)
    :ok
  end

  ## Helper Functions

  defp write_block(file, %CID{} = cid, data) do
    # TODO

    cid_string = Hexpds.CID.to_string(cid)
    data_length = byte_size(data)

    write_data = "#{cid_string}\n#{data_length}\n#{data}"

    case IO.binwrite(file, write_data) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
