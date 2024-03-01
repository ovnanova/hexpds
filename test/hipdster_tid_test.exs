defmodule HipdsterTidTest do
  use ExUnit.Case
  doctest Hipdster.Tid

  test "converts to string" do
    assert Hipdster.Tid.to_string(%Hipdster.Tid{timestamp: 1706732639995761, clock_id: 243}) == "3kkciofrlvlbn"
  end

  test "converts from string" do
    assert Hipdster.Tid.from_string("3kkciofrlvlbn") == %Hipdster.Tid{timestamp: 1706732639995761, clock_id: 243}
  end

end
