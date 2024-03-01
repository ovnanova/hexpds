defmodule Hipdster.DidPlc do
  defmodule Operation do
    defstruct [
      :rotationKeys,
      :prev,
      :verificationMethods,
      :alsoKnownAs,
      :services,
      type: "plc_operation"
    ]

    @type t :: %__MODULE__{
            rotationKeys: [Hipdster.K256.PrivateKey.t()],
            prev: String.t() | nil,
            verificationMethods: VerificationMethods.t(),
            alsoKnownAs: [String.t()],
            services: Services.t(),
            type: String.t()
          }

    defmodule VerificationMethods do
      defstruct([:atproto])
      @type t :: %__MODULE__{atproto: Hipdster.K256.PrivateKey.t()}
    end

    defmodule Services do
      @type t :: %__MODULE__{atproto_pds: AtprotoPds.t()}
      @derive Jason.Encoder
      defstruct [:atproto_pds]

      defmodule AtprotoPds do
        @type t :: %__MODULE__{endpoint: String.t(), type: String.t()}
        @derive Jason.Encoder
        defstruct [:endpoint, type: "AtprotoPersonalDataServer"]
      end
    end

    def genesis(
          %Hipdster.K256.PrivateKey{} = rotationkey,
          %Hipdster.K256.PrivateKey{} = signingkey,
          handle,
          pds
        ) do
      %__MODULE__{
        rotationKeys: [rotationkey],
        prev: nil,
        verificationMethods: %Operation.VerificationMethods{atproto: signingkey},
        alsoKnownAs: ["at://#{handle}"],
        services: %Services{atproto_pds: %Services.AtprotoPds{endpoint: "https://#{pds}"}}
      }
    end

    def to_json(%__MODULE__{} = operation) do
      encodekeys = fn k ->
        k |> Hipdster.K256.PrivateKey.to_pubkey() |> Hipdster.K256.PublicKey.to_did_key()
      end

      Jason.encode!(%{
        "type" => operation.type,
        "rotationKeys" => Enum.map(operation.rotationKeys, encodekeys),
        "prev" => operation.prev,
        "verificationMethods" => %{atproto: encodekeys.(operation.verificationMethods.atproto)},
        "alsoKnownAs" => operation.alsoKnownAs,
        "services" => operation.services
      })
    end

    @spec sign(t(), Hipdster.K256.PrivateKey.t()) ::
            {:ok, binary()} | {:error, String.t()}
    def sign(%__MODULE__{} = operation, %Hipdster.K256.PrivateKey{} = privkey) do
      with {:ok, cbor} <-
             operation
             |> to_json()
             |> Hipdster.DagCBOR.encode(),
           do:
             {:ok,
              privkey
              |> Hipdster.K256.PrivateKey.sign(cbor)
              |> Hipdster.K256.Signature.bytes()
              |> Base.url_encode64()
              |> String.replace("=", "")}
    end

    @spec add_sig(t(), Hipdster.K256.PrivateKey.t()) ::
            {:error, binary()} | map()
    def add_sig(%__MODULE__{} = operation, %Hipdster.K256.PrivateKey{} = privkey) do
      with {:ok, sig} <- sign(operation, privkey) do
        operation
        |> to_json
        |> Jason.decode!()
        |> Map.put("sig", sig)
      end
    end
  end
end
