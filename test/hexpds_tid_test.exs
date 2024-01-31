defmodule HexpdsTidTest do
  use ExUnit.Case
  doctest Hexpds.Tid

  test "converts to string" do
    assert Hexpds.Tid.to_string(%Hexpds.Tid{timestamp: 1706732639995761, clock_id: 243}) == "3kkciofrlvlbn"
  end

end
