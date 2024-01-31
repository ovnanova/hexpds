defmodule Hexpds.Tid do
  import Bitwise

  @type t :: %__MODULE__{timestamp: non_neg_integer(), clock_id: non_neg_integer()}
  defstruct [:timestamp, :clock_id]
  @b32_charset "234567abcdefghijklmnopqrstuvwxyz"

  @spec from_string(String.t()) :: t() | {:error, String.t()}
  def from_string(str) when is_binary(str) and byte_size(str) == 13 do
    try do
      timestamp = str
                  |> String.graphemes()
                  |> Enum.with_index()
                  |> Enum.reduce(0, fn {char, idx}, acc ->
                       b32_index = Enum.find_index(@b32_charset, fn c -> c == char end)
                       shift_amount = (12 - idx) * 5
                       acc ||| (b32_index <<< shift_amount)
                     end)
                  <<< 10

      clock_id = str
                 |> String.graphemes()
                 |> Enum.at(12)
                 |> String.to_integer(36)

      %__MODULE__{timestamp: timestamp, clock_id: clock_id}
    rescue
      _ -> {:error, "Invalid TID"}
    end
  end

  defimpl String.Chars, for: Hexpds.Tid do
    @spec to_string(Hexpds.Tid.t()) :: String.t()
    defdelegate to_string(tid), to: Hexpds.Tid
  end

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = tid) do
    tid_int = to_integer(tid)

    for i <- Enum.to_list(0..12) do
      @b32_charset
      |> String.graphemes()
      |> Enum.at(tid_int >>> (60 - i * 5) &&& 31)  # I'm not really sure what this does I just copied Retr0id
    end
    |> Enum.join
  end

  @spec to_integer(Hexpds.Tid.t()) :: integer()
  def to_integer(%__MODULE__{timestamp: t, clock_id: c}) do
    t <<< 10 ||| c
  end

  @spec now() :: t()
  def now do
    %__MODULE__{timestamp: :os.system_time(:microsecond), clock_id: :rand.uniform(1 <<< 10)}
  end
end
