defmodule Hipdster.Auth do
  @moduledoc """
  Authentication and session management
  Should the database stuff for *users* specifically go here?
  """

  def generate_session(_, username, pw) do
    %{
      error: "MethodNotImplemented",
      message: "Not implemented yet"
    }
  end

end
