defmodule Hipdster.Auth.Context do
  @moduledoc """
  A struct containing some context for a request,
  such as the currently logged in user, the app password
  used, whether it's a refresh or access token, and
  probably more
  """

  defstruct [
    :authed,
    :user,
    :is_app_pwd?,
    :app_password_name,
    :token_type
  ]

  @type token_type() :: :access | :refresh

  @type t :: %__MODULE__{
          authed: boolean(),
          user: Hipdster.User.t() | nil,
          is_app_pwd?: boolean(),
          app_password_name: String.t() | nil,
          token_type: token_type() | nil
        }

  def authed?(%__MODULE__{authed: authed}), do: authed

  def app_pwd?(%__MODULE__{is_app_pwd?: is_app_pwd?}), do: is_app_pwd?

  def parse_jwt(jwt, hs256_secret \\ Application.get_env(:hipdster, :jwt_key)) do
    Hipdster.Auth.Session.verify(jwt, hs256_secret)
    |> json_to_ctx()
  end

  def unauthed(), do: %__MODULE__{
    authed: false,
    user: nil,
    is_app_pwd?: false,
    app_password_name: nil,
    token_type: nil
  }

  defp json_to_ctx({:error, _}),
    do: unauthed()

  defp json_to_ctx(%{
         "iss" => did,
         "sub" => %{"pwd" => app_password_name, "scope" => scope}
       }) do
    %{is_app_pwd?: is_app_pwd, app_password_name: app_password_name} =
      app_password(app_password_name)

    %__MODULE__{
      authed: true,
      user: Hipdster.User.get(did),
      is_app_pwd?: is_app_pwd,
      app_password_name: app_password_name,
      token_type: token_type(scope)
    }
  end

  defp app_password("main"), do: %{is_app_pwd?: false, app_password_name: nil}

  defp app_password(<<>> <> app_password_name),
    do: %{is_app_pwd?: true, app_password_name: app_password_name}

  defp token_type("com.atproto.access"), do: :access
  defp token_type("com.atproto.refresh"), do: :refresh


  def parse_header(nil), do: unauthed()
  def parse_header("Bearer " <> jwt), do: parse_jwt(jwt)
  def parse_header(_), do: unauthed()

end
