defmodule Hipdster.Auth.User do
  alias Hipdster.K256

  @fields [:did,
  :handle,
  :password_hash,
  :signing_key,
  :rotation_key,
  :data]

  use Memento.Table,
    attributes: @fields,
    index: [:handle],
    type: :set


  defmodule Data do
    defstruct preferences: %{}

    @moduledoc """
    The data associated with a user, like preferences. Mostly
    just here to prevent the mnesia table definition from getting
    out of hand. Who knows, this may all disappear and be replaced by
    postgres anyways.
    """

    @type t :: %__MODULE__{preferences: map()}
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

  defmodule CreateOpts do
    @moduledoc """
    Options for `Hipdster.Auth.User.create/1`
    Because sometimes the input to create will
    be more complex than just a handle and password
    """
    defstruct [:handle, :password]
    @type t :: %__MODULE__{handle: String.t(), password: String.t()}
  end


  @spec create(String.t(), String.t()) :: Hipdster.Auth.User.t()
  def create(handle, pw) do
    %{did: did, signing_key: signing_key, rotation_key: rotation_key} =
      Hipdster.DidGenerator.generate_did(handle)

    %__MODULE__{
      did: did,
      handle: handle,
      password_hash: Argon2.hash_pwd_salt(pw),
      signing_key: signing_key |> K256.PrivateKey.from_hex(),
      rotation_key: rotation_key |> K256.PrivateKey.from_hex(),
      data: %__MODULE__.Data{}
    }
    |> tap(&Hipdster.Auth.DB.create_user/1)
  end

  @spec create(Hipdster.Auth.User.CreateOpts.t()) :: Hipdster.Auth.User.t()
  def create(%__MODULE__.CreateOpts{handle: handle, password: pw}) do
    create(handle, pw)
  end

  @spec authenticate(String.t(), String.t()) :: false | Hipdster.Auth.User.t()
  def authenticate(username, pw) do
    with %__MODULE__{password_hash: hash} = user <- Hipdster.Auth.DB.get_user(username),
         true <- Argon2.verify_pass(pw, hash) do
      user
    else
      _ -> false
    end
  end
end
