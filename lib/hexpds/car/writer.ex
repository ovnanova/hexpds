defmodule Hexpds.Car.Writer do
  @moduledoc """
  Module for writing data blocks to a CAR stream.
  """

  alias Hexpds.CID

  @doc """
  Writes a block to the CAR stream.

  ## Parameters

    - `car`: The CAR writer process or handle.
    - `cid`: The CID of the data block.
    - `serialized_entries`: The binary data to write.

  ## Returns

    - `:ok` on success.
    - `{:error, reason}` on failure.

  ## Examples

      iex> Hexpds.Car.Writer.put(car_writer, cid, serialized_data)
      :ok
  """
  @spec put(car :: pid() | atom(), cid :: CID.t(), serialized_entries :: binary()) :: :ok | {:error, term()}
  def put(car, %CID{} = cid, serialized_entries) when is_binary(serialized_entries) do
    # TODO
    GenServer.call(car, {:put, cid, serialized_entries})
  rescue
    e ->
      {:error, "Failed to write to CAR stream: #{inspect(e)}"}
  end
end
