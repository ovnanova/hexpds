defmodule Ecto.Type.ErlangTerm do
  @moduledoc """
  A custom Ecto type for handling the serialization of arbitrary
  data types stored as binary data in the database. Requires the
  underlying DB field to be a binary.
  Taken from https://fly.io/phoenix-files/exploring-options-for-storing-custom-data-in-ecto/
  """
  use Ecto.Type
  def type, do: :binary

  @doc """
  Provides custom casting rules for params. Nothing changes here.
  We only need to handle deserialization.
  """
  def cast(:any, term), do: {:ok, term}
  def cast(term), do: {:ok, term}

  @doc """
  Convert the raw binary value from the database back to
  the desired term.
  """
  def load(raw_binary) when is_binary(raw_binary),
    do:
      {:ok,
       raw_binary
       |> :zlib.gunzip()
       |> :erlang.binary_to_term()}

  @doc """
  Converting the data structure to binary for storage.
  """
  def dump(term),
    do:
      {:ok,
       term
       |> :erlang.term_to_binary()
       |> :zlib.gzip()}
end
