defmodule Hipdster.Auth do
  @moduledoc """
  Authentication and session management
  """

  def generate_session(_, _username, _pw) do
    %{
      error: "MethodNotImplemented",
      message: "Not implemented yet"
    }
  end

  def admin_auth("Basic " <> credentials) do
    with {:ok, creds} <- Base.decode64(credentials),
         ["admin", password] <- String.split(creds, ":") do
      Application.get_env(:hipdster, :admin_password) == password
    else
      _ -> false
    end
  end
end
