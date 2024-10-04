defmodule HexpdsMstHelpersTest do
  use ExUnit.Case
  doctest Hexpds.Repo.Helpers

  test "gets correct depth for paths" do
    assert Hexpds.Repo.Helpers.key_depth("2653ae71") == 0
    assert Hexpds.Repo.Helpers.key_depth("blue") == 1
    assert Hexpds.Repo.Helpers.key_depth("app.bsky.feed.post/454397e440ec") == 4
    assert Hexpds.Repo.Helpers.key_depth("app.bsky.feed.post/9adeb165882c") == 8
  end
end
