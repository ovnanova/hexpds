defmodule Hexpds.Auth.Session do
  require Matcha

  use Memento.Table,
    attributes: [:refresh_jwt, :access_jwt, :did],
    index: [:access_jwt, :did],
    type: :set

  @type t :: %__MODULE__{
          refresh_jwt: String.t(),
          access_jwt: String.t(),
          did: Hexpds.Identity.did()
        }

  def new(uname) do
    %{did: did, refreshJwt: r_jwt, accessJwt: a_jwt} =
      resp =
      Hexpds.User.get(uname)
      |> Hexpds.Auth.generate_session()

    sess = %__MODULE__{refresh_jwt: r_jwt, access_jwt: a_jwt, did: did}

    Memento.transaction!(fn ->
      Memento.Query.write(sess)
    end)

    resp
  end

  def new(uname, pw) do
    if Hexpds.User.authenticate(uname, pw) do
      new(uname)
    end
  end

  def find_r_jwt(jwt) do
    Memento.transaction!(fn ->
      Memento.Query.select_raw(
        __MODULE__,
        (Matcha.spec do
           {__MODULE__, ^jwt, _, _} = ses -> ses
         end).source
      )
    end)
    |> List.first()
  end

  def find_a_jwt(jwt) do
    Memento.transaction!(fn ->
      Memento.Query.select_raw(
        __MODULE__,
        (Matcha.spec do
           {__MODULE__, _, ^jwt, _} = ses -> ses
         end).source
      )
    end)
    |> List.first()
  end

  def delete(jwt) do
    if find_r_jwt(jwt) do
      Memento.transaction!(fn ->
        Memento.Query.delete(__MODULE__, jwt)
      end)
    else
      :error
    end
  end

  def refresh(r_jwt) do
    case find_r_jwt(r_jwt) do
      nil ->
        {:error, "Invalid token"}

      %{did: did} ->
        delete(r_jwt)
        new(did)
    end
  end

  def verify(jwt, hs256 \\ Application.get_env(:hexpds, :jwt_key)) do
    Hexpds.Auth.JWT.verify(jwt, hs256)
    |> case do
      {:error, reason} ->
        {:error, reason}

      json ->
        case json["scope"] do
          "com.atproto.access" -> if find_r_jwt(jwt), do: json, else: {:error, "Invalid token"}
          "com.atproto.refresh" -> if find_a_jwt(jwt), do: json, else: {:error, "Invalid token"}
          _ -> {:error, "Invalid scope"}
        end
    end
  end
end
