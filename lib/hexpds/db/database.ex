defmodule Hexpds.Database do
  @moduledoc """
  This is an Ecto Repo!
  The term `Repo` is not used here
  to avoid confusion with ATProto Repos.
  """

  use Ecto.Repo,
    otp_app: :hexpds,
    adapter: Application.compile_env(:hexpds, :ecto_adapter)
end
