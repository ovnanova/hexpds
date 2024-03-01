defmodule Hipdster.Tid do
  import Bitwise

  defstruct [:timestamp, :clock_id]

  @typedoc """
    A TID is a 13-character string.
    TID is short for "timestamp identifier," and the name is derived from the creation time of the record.

    The characteristics of a TID are:

    - 64-bit integer
    - big-endian byte ordering
    - encoded as base32-sortable. That is, encoded with characters 234567abcdefghijklmnopqrstuvwxyz, with no padding, yielding 13 ASCII characters.
    - hyphens should not be included in a TID (unlike in previous iterations of the scheme)

    The layout of the 64-bit integer is:

    - The top bit is always 0
    - The next 53 bits represent microseconds since the UNIX epoch. 53 bits is chosen as the maximum safe integer precision in a 64-bit floating point number, as used by Javascript.
    - The final 10 bits are a random "clock identifier."

    This struct holds the timestamp in microseconds since the UNIX epoch, and the clock_id, which is a random number in the range 0..1023.

  """
  @type t :: %__MODULE__{timestamp: unix_microseconds(), clock_id: non_neg_integer()}

  @typedoc """
  A number of microseconds since the UNIX epoch, as a 64-bit non-negative integer
  """
  @type unix_microseconds :: non_neg_integer()

  @b32_charset "234567abcdefghijklmnopqrstuvwxyz"

  @spec from_string(String.t()) :: t() | {:error, String.t()}
  def from_string(str) when is_binary(str) and byte_size(str) == 13 do
    try do
      {timestamp, clock_id} =
        str
        |> String.graphemes()
        |> Enum.with_index()
        |> Enum.reduce({0, 0}, fn {char, index}, {timestamp_acc, clock_id_acc} ->
          case {index, find_index(@b32_charset, char)} do
            {i, pos} when i < 11 ->
              {timestamp_acc <<< 5 ||| (pos &&& 0x1F), clock_id_acc}

            {i, pos} when i >= 11 ->
              {timestamp_acc, clock_id_acc <<< 5 ||| (pos &&& 0x1F)}

            _ ->
              throw("Invalid TID")
          end
        end)

      %__MODULE__{timestamp: timestamp, clock_id: clock_id}
    catch
      :throw, e -> {:error, e}
    end
  end

  # Helper function to find index of a character in a string
  defp find_index(string, char) do
    case :binary.match(string, char) do
      {index, 1} -> index
      _ -> raise "No such character in string"
    end
  end

  defimpl String.Chars, for: Hipdster.Tid do
    @spec to_string(Hipdster.Tid.t()) :: String.t()
    defdelegate to_string(tid), to: Hipdster.Tid
  end

  @doc """
    Through this loop, the 60-bit `tid_int` is split into 13 segments (each 5 bits long), and each segment is encoded into a single Base32 character.
    The result is a 13-character Base32 encoded string.

    - Each iteration shifts `tid_int` right by a decreasing number of bits.
    - `tid_int` in the atproto spec is a 64-bit integer.
    - Since we are operating in 5-bit chunks, we round the bits up to the nearest multiple of 5 (0..12 * 5 bits = 65 bits).
    - This makes `tid_int` a 65-bit integer in this context. The final bit is always 0.
    - We subtract 5 to prevent `tid_int` from being off, so the shift starts with 60 bits (65-5).
    - `tid_int` decreases by 5 bits with each iteration. This progressively shifts the next 5-bit segment of `tid_int` into the rightmost position.

    - `&&& 31` isolates the 5 rightmost bits of the shifted `tid_int`.
    - Since 31 in binary is 11111, the AND operation masks all but the 5 least significant bits.
    - The result is an integer between 0 and 31, representing one of 32 possible values in a 5-bit range.

    - The resulting 5-bit integer is used as an index to access a character in the `@b32_charset`.
    - The `@b32_charset` contains 32 unique characters, corresponding to the 32 possible values of a 5-bit number.
    - This maps each 5-bit segment of `tid_int` to a specific character in the Base32 encoding.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = tid) do
    tid_int = to_integer(tid)

    for i <- Enum.to_list(0..12) do
      @b32_charset
      |> String.graphemes()
      |> Enum.at(tid_int >>> (60 - i * 5) &&& 31)
    end
    |> Enum.join()
  end

  @doc """
    - The timestamp `t` is left-shifted by 10 bits. This makes room for the `clock_id` in the lower 10 bits.
    - Then, the `clock_id` `c` is combined into this value using the bitwise OR operation.
    - Resulting integer combines both the timestamp and clock_id in a single integer.
  """
  @spec to_integer(Hipdster.Tid.t()) :: integer()
  def to_integer(%__MODULE__{timestamp: t, clock_id: c}) do
    t <<< 10 ||| c
  end

  @spec now() :: t()
  def now do
    %__MODULE__{timestamp: :os.system_time(:microsecond), clock_id: :rand.uniform(1 <<< 10)}
  end
end
