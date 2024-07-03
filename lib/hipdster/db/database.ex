defmodule Hipdster.Database do
  @moduledoc """
  This is an Ecto Repo!
  The term `Repo` is not used here
  to avoid confusion with ATProto Repos.
  """

  use Ecto.Repo,
    otp_app: :hipdster,
    adapter: Application.compile_env(:hipdster, :ecto_adapter)
end
