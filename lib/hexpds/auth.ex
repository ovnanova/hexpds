defmodule Hexpds.Auth do
  @moduledoc """
  Authentication and session management
  """
  alias Hexpds.User

  def generate_session(_, username, pw) do
    if Hexpds.User.authenticate(username, pw) do
      Hexpds.User.get(username)
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
      accessJwt: Hexpds.Auth.JWT.access_jwt(u, "main"),
      refreshJwt: Hexpds.Auth.JWT.refresh_jwt(u, "main"),
      handle: handle,
      did: did
    }
  end

  def admin_auth("Basic " <> credentials) do
    with {:ok, creds} <- Base.decode64(credentials),
         ["admin", password] <- String.split(creds, ":") do
      Application.get_env(:hexpds, :admin_password) == password
    else
      _ -> false
    end
  end
end
