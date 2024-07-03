defmodule Hipdster.Auth do
  @moduledoc """
  Authentication and session management
  """
alias Hipdster.User

  def generate_session(_, username, pw) do
    if Hipdster.User.authenticate(username, pw) do
      Hipdster.User.get(username)
      |> generate_session()
    else
      %{
        error: "AuthenticationRequired",
        message: "Invalid identifier or password"
      }
    end
  end

  def generate_session(%User{handle: handle, did: did} = u) do
    %{
      accessJwt: Hipdster.Auth.JWT.access_jwt(u, "main"),
      refreshJwt: Hipdster.Auth.JWT.refresh_jwt(u, "main"),
      handle: handle,
      did: did
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
