defmodule Ecto.Types.Cid do
  alias Hexpds.CID
  use Ecto.Type

  def type, do: :binary
  def cast(:any, term), do: {:ok, term}
  def cast(term), do: {:ok, term}

  def load(term) when is_binary(term) do
    {:ok,
     term
     |> CID.decode_cid!()}
  end

  def dump(term),
    do:
      {:ok,
       term
       |> Hexpds.Repo.Helpers.cid_string}
end
