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
                     b32_index = Enum.find_index(String.graphemes(@b32_charset), fn c -> c == char end)
                     shift_amount = (12 - idx) * 5
                     acc ||| (b32_index <<< shift_amount)
                   end)
                <<< 10

    clock_id = str
               |> String.graphemes()
               |> Enum.at(12)
               |> String.at(0)
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
      @doc """
      Through this loop, the 60-bit `tid_int` is split into 13 segments (each 5 bits long), and each segment is encoded into a single Base32 character.
      The result is a 13-character Base32 encoded string.
      """
      @b32_charset
      |> String.graphemes()
      |> Enum.at(tid_int >>> (60 - i * 5) &&& 31)
      @doc """
      - Each iteration shifts `tid_int` right by a decreasing number of bits.
      - tid_int is 65-bits long, but the 65th bit is always 0.
      - The shift starts with 60 bits, decreasing by 5 bits with each iteration.
      - This progressively shifts the next 5-bit segment of `tid_int` into the rightmost position.

      - `&&& 31` isolates the 5 rightmost bits of the shifted `tid_int`.
      - Since 31 in binary is 11111, the AND operation masks all but the 5 least significant bits.
      - The result is an integer between 0 and 31, representing one of 32 possible values in a 5-bit range.

      - The resulting 5-bit integer is used as an index to access a character in the `@b32_charset`.
      - The `@b32_charset` contains 32 unique characters, corresponding to the 32 possible values of a 5-bit number.
      - This maps each 5-bit segment of `tid_int` to a specific character in the Base32 encoding.
      """
    end
    |> Enum.join
  end

  @spec to_integer(Hexpds.Tid.t()) :: integer()
  def to_integer(%__MODULE__{timestamp: t, clock_id: c}) do
    t <<< 10 ||| c
    @doc """
    - The timestamp `t` is left-shifted by 10 bits. This makes room for the `clock_id` in the lower 10 bits.
    - Then, the `clock_id` `c` is combined into this value using the bitwise OR operation.
    - Resulting integer combines both the timestamp and clock_id in a single integer.
    """
  end

  @spec now() :: t()
  def now do
    %__MODULE__{timestamp: :os.system_time(:microsecond), clock_id: :rand.uniform(1 <<< 10)}
  end
end
