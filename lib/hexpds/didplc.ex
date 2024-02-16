defmodule Hexpds.DidPlc do
  defmodule Operation do
    defstruct [
      :rotationKeys,
      :prev,
      :verificationMethods,
      :alsoKnownAs,
      :did,
      :sig,
      :services,
      type: "plc_operation"
    ]

    @type t :: %__MODULE__{
            rotationKeys: [Hexpds.K256.PrivateKey.t()],
            prev: String.t() | nil,
            verificationMethods: VerificationMethods.t(),
            alsoKnownAs: [String.t()],
            did: String.t(),
            sig: String.t(),
            services: Services.t(),
            type: String.t()
          }

    defmodule VerificationMethods do
      defstruct([:atproto])
      @type t :: %__MODULE__{atproto: Hexpds.K256.PrivateKey.t()}
    end

    defmodule Services do
      @type t :: %__MODULE__{atproto_pds: AtprotoPds.t()}
      defstruct [:atproto_pds]

      defmodule AtprotoPds do
        @type t :: %__MODULE__{endpoint: String.t(), type: String.t()}
        defstruct [:endpoint, type: "AtprotoPersonalDataServer"]
      end
    end
  end



end
