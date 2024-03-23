defmodule Hipdster.Auth.User do
  defstruct [:did, :password_hash, :handle, :signing_key, :rotation_key]
end
