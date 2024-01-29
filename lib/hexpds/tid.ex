defmodule Hexpds.Tid do
  import Bitwise
  @type t :: %__MODULE__{timestamp: non_neg_integer(), clock_id: non_neg_integer()}
  defstruct [:timestamp, :clock_id]
  @b32_charset "abcdefghijklmnopqrstuvwxyz234567"

  @spec from_string(String.t()) :: t | {:error, String.t()}
  def from_string(str) when is_binary(str) and byte_size(str) == 13 do
    try do
      timestamp =
        str
        |> String.slice(0..9)
        |> Base.decode32!()

      clock_id =
        str
        |> String.slice(10..12)
        |> Base.decode32!()

      %__MODULE__{timestamp: timestamp, clock_id: clock_id}
    rescue
      _ -> {:error, "Invalid TID format"}
    end
  end

  defimpl String.Chars, for: Hexpds.Tid do
    @spec to_string(Hexpds.Tid.t()) :: String.t()
    def to_string(%Hexpds.Tid{} = tid),
      do: Hexpds.Tid.to_string(tid)
  end

  @spec now() :: t()
  def now(),
    do: %__MODULE__{
      timestamp: :os.system_time(:microsecond),
      clock_id: :rand.uniform(1 <<< 10)
    }

  defp char_at(tid_int, i) do
    @b32_charset
    |> String.to_charlist()
    |> Enum.at(tid_int >>> (60 - i * 5) &&& 31)
  end

  @spec to_string(Hexpds.Tid.t()) :: String.t()
  def to_string(%Hexpds.Tid{timestamp: t, clock_id: c}),
    do: Enum.join(for i <- Enum.to_list(0..12), do: char_at(t <<< 10 ||| c, i))
end
