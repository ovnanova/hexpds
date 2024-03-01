defmodule Hipdster.Multicodec do
  use GenServer

  def start_link(multicodec_csv \\ Application.get_env(:hipdster, :multicodec_csv_path)) do
    GenServer.start_link(__MODULE__, multicodec_csv, name: __MODULE__)
  end

  @impl GenServer
  def init(csv_path) do
    {:ok,
     csv_path
     |> File.stream!()
     |> read_csv()}
  end

  @impl GenServer
  def handle_call(:multicodec_map, _from, state) do
    {:reply, state, state}
  end

  def read_csv(%File.Stream{} = csv) do
    csv
    |> Stream.map(&String.replace(&1, " ", ""))
    |> Stream.map(&String.split(&1, ",", trim: true))
    |> Enum.reduce(%{}, fn [name, _tag, "0x" <> code, _status], acc ->
      Map.put(acc, String.to_atom(name), Integer.parse(code, 16) |> elem(0))
    end)
  end

  def multicodec_map() do
    GenServer.call(__MODULE__, :multicodec_map)
  end

  def bytes_to_codec() do
    for {codec, bytes} <- multicodec_map(), into: %{} do
      {bytes, codec}
    end
  end

  def encode!(bytes, "" <> codec) do
    <<Varint.LEB128.encode(multicodec_map()[String.to_atom(codec)])::binary, bytes::binary>>
  end

  def encode!(bytes, codec) do
    encode!(bytes, to_string(codec))
  end

  @spec encode(binary(), String.t() | atom()) ::
          {:error, any()} | {:ok, binary()}
  def encode(b, c) do
    try do
      {:ok, encode!(b, c)}
    catch
      _, e -> {:error, e}
    end
  end

  def codec_decode("" <> encoded) do
    try do
      with {prefix, rest} <- Varint.LEB128.decode(<<encoded::binary>>),
           codec <- bytes_to_codec()[prefix],
           do: {:ok, {rest, to_string(codec)}}
    catch
      _, e -> {:error, e}
    end
  end

  @spec codec?(binary()) :: boolean()
  def codec?("" <> codec) do
    Map.has_key?(multicodec_map(), String.to_atom(codec))
  end

  def codecs do
    multicodec_map()
    |> Map.keys()
    |> Enum.map(&to_string/1)
  end
end
