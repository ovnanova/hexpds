defmodule Hipdster.User do
  @moduledoc """
  A user in the database
  """
  alias Hipdster.K256

  use Ecto.Schema
  import Ecto.Query

  schema "users" do
    field(:did, :string)
    field(:handle, :string)
    field(:password_hash, :string)
    field(:signing_key, Ecto.Type.ErlangTerm)
    field(:rotation_key, Ecto.Type.ErlangTerm)
    field(:data, :map)
  end

  @type key :: Hipdster.K256.PrivateKey.t() | Hipdster.K256.PublicKey.t()

  @type signing_key :: key()
  @type rotation_key :: key()

  @type t :: %__MODULE__{
    did: Hipdster.Identity.did(),
    handle: String.t(),
    password_hash: String.t(),
    signing_key: signing_key(),
    rotation_key: rotation_key() | [rotation_key()],
    data: Hipdster.Auth.User.Data.t()
  }

  def get("did:" <> _ = did) do
    from(u in __MODULE__,
      where: u.did == ^did,
      select: u
    )
    |> Hipdster.Database.one()
  end

  def get(handle) do
    from(u in __MODULE__,
      where: u.handle == ^handle,
      select: u
    )
    |> Hipdster.Database.one()
  end

  def authenticate(username, pw) do
    with %__MODULE__{password_hash: hash} = user <- get(username),
         true <- Argon2.verify_pass(pw, hash) do
      user
    else
      _ -> false
    end
  end

  def create(handle, pw) do
    %{did: did, signing_key: signing_key, rotation_key: rotation_key} =
      Hipdster.DidGenerator.generate_did(handle)

    %__MODULE__{
      did: did,
      handle: handle,
      password_hash: Argon2.hash_pwd_salt(pw),
      signing_key: signing_key |> K256.PrivateKey.from_hex(),
      rotation_key: rotation_key |> K256.PrivateKey.from_hex(),
      data: %{"preferences" => %{}}
    }
    |> tap(&Hipdster.Database.insert/1)
  end
end
