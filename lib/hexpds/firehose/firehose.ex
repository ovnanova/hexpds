defmodule Hexpds.Firehose do
  defp cbor_concat(header, op) do
    [header, op]
    |> Enum.map(&Hexpds.DagCBOR.encode!/1)
    |> Enum.reverse()
    |> Enum.reduce(&<>/2)
  end

  def error(type, message \\ nil) do
    cbor_concat(%{op: -1}, optional_join(%{error: type}, if(message, do: %{message: message})))
  end

  defp optional_join(map, nil), do: map
  defp optional_join(map1, map2), do: Map.merge(map1, map2)

end
