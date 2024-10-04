defmodule Hexpds.CID do
  @moduledoc """
  CID - self-describing content-addressed identifiers for distributed systems.

  ## Overview

  Elixir version of [CID](https://github.com/ipld/cid). CID is currently being used as part of [IPFS](https://ipfs.io/) for identifying distributed content.

  > Self-describing content-addressed identifiers for distributed systems

  This module represents a CID as a CID struct, consisting of the following fields:

    * `multihash` - An encoded multihash, using `Multihash.encode/3` for example.
    * `version` - The CID version
    * `codec` - The Multicodec to use as part of CID

  The following are building blocks of this CID implementation (see Protocol Description):

    * `Multihash` - hashing content with a tagged identifier according to popular hashing algorithms, ex: `:sha2_256`
    * `Multicodec` - tagging content using a given `codec`
    * `Multibase` - tagged content encoding using a given `encoding_id`

  A CID struct is created by:

    * Multihashing some data according to a hashing algorithm such as `:sha2_256`
    * Selecting a `codec` name from `Multicodec` to describe the content
    * Selecting a `CID` version, usually the default (CID v1), but other versions may be selected less than the current version (ex: CID v0).

  ## Features

  The following functionality is provided in this module:

    * Encode/Decode CIDs
      * Encode a CID to a string
      * Encode a CID buffer to later Multibase encode
      * Decode a CID string to a CID and optionally, the Multibase encoding used
    * Create human readable CIDs for debugging and checking
    * Error handling and exception versions of most major API functions
    * Current support for all Multibase and Multicodec encodings
    * Elixir struct for CID data
      * Easy comparisons, construction, validation, etc.
      * Send over the wire
    * Consistent API
    * Support for CID v0 and CID v1

  ## How does it work? - Protocol Description

  CID is a self-describing content-addressed identifier. It uses cryptographic hashes to achieve content addressing. It uses several [multiformats](https://github.com/multiformats/multiformats) to achieve flexible self-description, namely [multihash](https://github.com/multiformats/multihash) for hashes, [multicodec](https://github.com/multiformats/multicodec) for data content types, and [multibase](https://github.com/multiformats/multibase) to encode the CID itself into strings.

  Current version: CIDv1

  A CIDv1 has four parts:

  ```sh
  <cidv1> ::= <mb><version><mc><mh>
  # or, expanded:
  <cidv1> ::= <multibase-prefix><cid-version><multicodec-content-type><multihash-content-address>
  ```
  Where

  - `<multibase-prefix>` is a [multibase](https://github.com/multiformats/multibase) code (1 or 2 bytes), to ease encoding CIDs into various bases.
  - `<cid-version>` is a [varint](https://github.com/multiformats/unsigned-varint) representing the version of CID, here for upgradability purposes.
  - `<multicodec-content-type>` is a [multicodec](https://github.com/multiformats/multicodec) code representing the content type or format of the data being addressed.
  - `<multihash-content-address>` is a [multihash](https://github.com/multiformats/multihash) value, representing the cryptographic hash of the content being addressed. Multihash enables CIDs to use many different cryptographic hash function, for upgradability and protocol agility purposes.


  ## Human Readable CIDs

  It is advantageous to have a human readable description of a CID, solely for the purposes of debugging and explanation. We can easily transform a CID to a "Human Readable CID" as follows:

  ```
  <hr-cid> ::= <hr-mbc> "-" <hr-cid-version> "-" <hr-mc> "-" <hr-mh>
  ```
  Where each sub-component is represented with its own human-readable form:

  - `<hr-mbc>` is a human-readable multibase code (eg `base58btc`)
  - `<hr-cid-version>` is the string `cidv#` (eg `cidv1` or `cidv2`)
  - `<hr-mc>` is a human-readable multicodec code (eg `cbor`)
  - `<hr-mh>` is a human-readable multihash (eg `sha2-256-256-abcdef0123456789...`)

  This module provides a human readable CID function via 'humanize/2'.

  ## Versions

  There are currently 2 active versions of CID, v0 and v1, each with different encoding and decoding algorithms. A CID v0 and CID v1 are not equal.

  This module intentionally avoids assumptions about future versions as a version change may necessitate dramatic encoding and decoding changes. As such, unknown versions will return an exception or error.

  ## General Usage

  Given a CID struct, it can be encoded by selecting an `encoding_id` from `Multibase`. For CID v0, only `:base58_btc` may be used. For CID v1, any base supported by Multibase is valid, for example `:base32_z`. Encoding a struct will produce a binary - a CID string representation. If you need to see the bytes, the string is just an Elixir binary and can be handled accordingly.

  Decoding a CID string is straight forward using `decode/1`, `decode!/1`, `decode_cid/1` or `decode_cid!/1`. Decoding only requires a CID string because all decode information is embedded.

  Inspecting a CID string for debugging or other purposes can be done by using `humanize/2`. It takes a custom separator to allow you to format the pieces to your liking. Decoding a CID back to a struct also is still very legible. `decode/1` offers additional information - the `Multibase` `encoding_id` that was used to encode the CID, while `decode_cid!/1` is just the bare CID struct.

  """

  alias Hexpds.Multicodec, as: Multicodec

  alias __MODULE__, as: CID

  @enforce_keys [:version, :codec, :multihash]

  defstruct [:version, :codec, :multihash]

  @typedoc """
  An encoded CID string.

  For CID v1:

  `<multibase-prefix><cid-version><multicodec-content-type><multihash-content-address>`

  For CID v0:

  `<multihash-content-address>`

  """
  @type cid_string() :: String.t()

  @typedoc """
  A Multihash encoded binary.
  """
  @type multihash_binary() :: binary()
  @type cid_version() :: 1 | 0

  @type t :: %__MODULE__{
          version: cid_version(),
          codec: Multicodec.multi_codec(),
          multihash: multihash_binary()
        }

  @current_version 1
  @v0_codec "dag-pb"
  @v0_encoding_id :base58_btc

  # bugs encountering Multihash + with
  @dialyzer {:no_match, [humanize: 2, do_cid: 3]}

  @doc """
  Creates a new CID.

  An error is returned if the provided parameters are invalid.

    * `codec` must correspond to a valid `Multicodec` codec name.
    * version 0 CIDs are checked for a valid `multihash` to avoid usage issues.
    * version 0 CIDs can only be created by specifying `dag-pb` (default) as the `codec`.

  ## Examples

      iex> CID.cid(<<17, 20, 86, 176, 173, 81, 245, 2, 26, 0, 52, 203, 228, 68, 33, 54, 171, 86, 201, 151, 184, 254>>, "dag-pb", 1)
      {:ok, %CID{
         codec: "dag-pb",
         multihash: <<17, 20, 86, 176, 173, 81, 245, 2, 26, 0, 52, 203, 228, 68, 33,
           54, 171, 86, 201, 151, 184, 254>>,
         version: 1
      }}

      iex> CID.cid(<<18, 32, 149, 184, 131, 27, 7, 230, 246, 113, 26, 45, 235, 92, 130, 235, 240, 88, 99, 208, 173, 179, 49, 200, 107, 43, 173, 200, 167, 153, 175, 31, 65, 149>>, "dag-pb", 0)
      {:ok, %CID{
       codec: "dag-pb",
       multihash: <<18, 32, 149, 184, 131, 27, 7, 230, 246, 113, 26, 45, 235, 92,
         130, 235, 240, 88, 99, 208, 173, 179, 49, 200, 107, 43, 173, 200, 167, 153,
         175, 31, 65, 149>>,
       version: 0
      }}

      iex> CID.cid("charcoal grills best", "dag-pb", 0)
      {:error, "Invalid hash code"}

      iex> CID.cid(<<18, 32, 149, 184, 131, 27, 7, 230, 246, 113, 26, 45, 235, 92, 130, 235, 240, 88, 99, 208, 173, 179, 49, 200, 107, 43, 173, 200, 167, 153, 175, 31, 65, 149>>, "dag-json", 0)
      {:error, :invalid_multicodec}

      iex> CID.cid(<<18, 32, 149, 184, 131, 27, 7, 230, 246, 113, 26, 45, 235, 92, 130, 235, 240, 88, 99, 208, 173, 179, 49, 200, 107, 43, 173, 200, 167, 153, 175, 31, 65, 149>>, "dag-json", 1)
      {:ok, %CID{
       codec: "dag-json",
       multihash: <<18, 32, 149, 184, 131, 27, 7, 230, 246, 113, 26, 45, 235, 92,
         130, 235, 240, 88, 99, 208, 173, 179, 49, 200, 107, 43, 173, 200, 167, 153,
         175, 31, 65, 149>>,
       version: 1
      }}

  """
  @spec cid(multihash_binary(), Multicodec.multi_codec(), cid_version()) ::
          {:ok, t()} | {:error, term()}
  def cid(multihash, codec \\ @v0_codec, version \\ @current_version)

  def cid(multihash, codec, version)
      when is_binary(multihash) and
             is_binary(codec) and
             is_integer(version) and version <= @current_version do
    if Multicodec.codec?(codec) do
      do_cid(multihash, codec, version)
    else
      {:error, :invalid_multicodec}
    end
  end

  def cid(_multihash, _codec, _version) do
    {:error, :unsupported_version}
  end

  @doc """
  Creates a new CID.

  An exception is raised if the provided parameters are invalid.

    * `codec` must correspond to a valid `Multicodec` codec name.
    * version 0 CIDs are checked for a valid `multihash` to avoid usage issues.
    * version 0 CIDs can only be created by specifying `dag-pb` (default) as the `codec`.

  ## Examples

      iex> CID.cid!(<<18, 32, 149, 184, 131, 27, 7, 230, 246, 113, 26, 45, 235, 92, 130, 235, 240, 88, 99, 208, 173, 179, 49, 200, 107, 43, 173, 200, 167, 153, 175, 31, 65, 149>>, "raw")
      %CID{
       codec: "raw",
       multihash: <<18, 32, 149, 184, 131, 27, 7, 230, 246, 113, 26, 45, 235, 92,
         130, 235, 240, 88, 99, 208, 173, 179, 49, 200, 107, 43, 173, 200, 167, 153,
         175, 31, 65, 149>>,
       version: 1
      }

      iex> CID.cid!(<<18, 32, 233, 5, 138, 177, 152, 246, 144, 143, 112, 33, 17, 176, 192, 251, 91,   54, 249, 157, 0, 85, 69, 33, 136, 108, 64, 226, 137, 27, 52, 157, 199, 161>>, "git-raw", 1)
      %CID{
      codec: "git-raw",
      multihash: <<18, 32, 233, 5, 138, 177, 152, 246, 144, 143, 112, 33, 17, 176,
        192, 251, 91, 54, 249, 157, 0, 85, 69, 33, 136, 108, 64, 226, 137, 27, 52,
        157, 199, 161>>,
      version: 1
      }

      iex> CID.cid!(<<18, 32, 233, 5, 138, 177, 152, 246, 144, 143, 112, 33, 17, 176, 192, 251, 91,   54, 249, 157, 0, 85, 69, 33, 136, 108, 64, 226, 137, 27, 52, 157, 199, 161>>, "dag-pb", 0)
      %CID{
      codec: "dag-pb",
      multihash: <<18, 32, 233, 5, 138, 177, 152, 246, 144, 143, 112, 33, 17, 176,
        192, 251, 91, 54, 249, 157, 0, 85, 69, 33, 136, 108, 64, 226, 137, 27, 52,
        157, 199, 161>>,
      version: 0
      }

  """
  @spec cid!(multihash_binary(), Multicodec.multi_codec(), cid_version()) :: t()
  def cid!(multihash, codec \\ @v0_codec, version \\ @current_version) do
    case cid(multihash, codec, version) do
      {:ok, cid} -> cid
      {:error, reason} -> raise ArgumentError, "invalid cid data - #{inspect(reason)}"
    end
  end

  @spec do_cid(multihash_binary(), Multicodec.multi_codec(), cid_version()) ::
          {:ok, t()} | {:error, term()}
  defp do_cid(multihash, codec, version)

  defp do_cid(multihash, @v0_codec, 0) do
    case Multihash.decode(multihash) do
      # ensure this hash is valid for CID v0 to avoid later complications when decoding
      {:ok, %Multihash{length: length}} when length == 32 ->
        {:ok, %CID{version: 0, codec: @v0_codec, multihash: multihash}}

      {:ok, %Multihash{}} ->
        {:error, :invalid_multihash}

      {:error, _reason} = err ->
        err
    end
  end

  defp do_cid(multihash, codec, 1) do
    {:ok, %CID{version: 1, codec: codec, multihash: multihash}}
  end

  defp do_cid(_multihash, _codec, 0) do
    {:error, :invalid_multicodec}
  end

  defp do_cid(_multihash, _codec, _version) do
    {:error, :unsupported_version}
  end

  @doc """
  Encodes a CID as a Multibase encoded string.

  Returns an error if the CID is invalid and cannot be encoded.

  ## Examples

      iex> CID.encode(%CID{codec: "dag-pb", multihash: <<18, 32, 233, 5, 138, 177, 152, 246, 144, 143, 112, 33, 17, 176, 192, 251, 91, 54, 249, 157, 0, 85, 69, 33, 136, 108, 64, 226, 137, 27, 52, 157, 199, 161>>, version: 0})
      {:ok, "Qme2Gc15TFi3XEbU87WT9zXDfAYPJQku8vpUkjFaoZsttQ"}

      iex> CID.encode(%CID{codec: "dag-json", multihash: <<17, 20, 196, 25, 117, 209, 218, 225, 204, 105, 177, 106, 216, 137, 43, 140, 119, 22, 78, 132, 202, 57>>, version: 1}, :base64_url)
      {:ok, "uAakCERTEGXXR2uHMabFq2IkrjHcWToTKOQ"}

      iex> CID.encode(%CID{codec: "dag-json", multihash: <<17, 20, 196, 25, 117, 209, 218, 225, 204, 105, 177, 106, 216, 137, 43, 140, 119, 22, 78, 132, 202, 57>>, version: 1}, :does_not_exist_codec)
      {:error, :unsupported_encoding}

  """
  @spec encode(t(), Multibase.encoding_id()) :: {:ok, cid_string()} | {:error, term()}
  def encode(cid, encoding_id \\ @v0_encoding_id) when is_map(cid) and is_atom(encoding_id) do
    do_encode(cid, encoding_id)
  end

  @spec encode!(Hexpds.CID.t()) :: binary()
  @doc """
  Encodes a CID as a Multibase encoded string.

  Raises an exception if the CID is invalid and cannot be encoded.

  ## Examples

      iex> CID.encode!(%CID{codec: "dag-pb", multihash: <<18, 32, 233, 5, 138, 177, 152, 246, 144, 143, 112, 33, 17, 176, 192, 251, 91, 54, 249, 157, 0, 85, 69, 33, 136, 108, 64, 226, 137, 27, 52, 157, 199, 161>>, version: 0})
      "Qme2Gc15TFi3XEbU87WT9zXDfAYPJQku8vpUkjFaoZsttQ"

      iex> CID.encode!( %CID{codec: "dag-json", multihash: <<17, 20, 196, 25, 117, 209, 218, 225, 204, 105, 177, 106, 216, 137, 43, 140, 119, 22, 78, 132, 202, 57>>, version: 1}, :base64_url)
      "uAakCERTEGXXR2uHMabFq2IkrjHcWToTKOQ"

      iex> CID.cid!( <<18, 32, 233, 5, 138, 177, 152, 246, 144, 143, 112, 33, 17, 176, 192, 251, 91, 54, 249, 157, 0, 85, 69, 33, 136, 108, 64, 226, 137, 27, 52, 157, 199, 161>>, "dag-pb", 0) |> CID.encode!(:base58_btc)
      "Qme2Gc15TFi3XEbU87WT9zXDfAYPJQku8vpUkjFaoZsttQ"

  """
  @spec encode!(t(), Multibase.encoding_id()) :: cid_string()
  def encode!(cid, encoding_id \\ @v0_encoding_id) do
    case encode(cid, encoding_id) do
      {:ok, cid_string} ->
        cid_string

      {:error, reason} ->
        raise ArgumentError, "unable to encode cid - #{inspect(reason)}"
    end
  end

  defp do_encode(%{version: 0} = cid, @v0_encoding_id) do
    do_encode_buffer(cid)
  end

  defp do_encode(%{version: 0}, _encoding_id) do
    # "CID version 0 may only be encoded with :base58_btc. It does not take a multibase prefix."
    {:error, :invalid_encoding}
  end

  defp do_encode(cid, encoding_id) do
    with {:ok, encoded_buffer} <- do_encode_buffer(cid) do
      Multibase.encode(encoded_buffer, encoding_id)
    end
  end

  @doc """
  Encodes a CID as a raw buffer to be encoded with Multibase.

  Raises an error if the CID is invalid and cannot be encoded.

  ## Examples

      iex> CID.cid!( <<18, 32, 233, 5, 138, 177, 152, 246, 144, 143, 112, 33, 17, 176, 192, 251, 91,   54, 249, 157, 0, 85, 69, 33, 136, 108, 64, 226, 137, 27, 52, 157, 199, 161>>, "dag-pb", 1) |> CID.encode_buffer()
      {:ok,
      <<1, 112, 18, 32, 233, 5, 138, 177, 152, 246, 144, 143, 112, 33, 17, 176, 192,
       251, 91, 54, 249, 157, 0, 85, 69, 33, 136, 108, 64, 226, 137, 27, 52, 157,
       199, 161>>}

      iex> CID.cid!( <<18, 32, 233, 5, 138, 177, 152, 246, 144, 143, 112, 33, 17, 176, 192, 251, 91,   54, 249, 157, 0, 85, 69, 33, 136, 108, 64, 226, 137, 27, 52, 157, 199, 161>>, "dag-pb", 0) |> CID.encode_buffer()
      {:ok, "Qme2Gc15TFi3XEbU87WT9zXDfAYPJQku8vpUkjFaoZsttQ"}

  """
  @spec encode_buffer(t()) :: {:ok, binary()} | {:error, term()}
  def encode_buffer(cid) when is_map(cid) do
    do_encode_buffer(cid)
  end

  @spec encode_buffer!(Hexpds.CID.t()) :: binary()
  @doc """
  Encodes a CID as a raw buffer to be encoded with Multibase.

  Raises an error if the CID is invalid and cannot be encoded.

  ## Examples

      iex>  CID.cid!( <<18, 32, 60, 41, 252, 52, 100, 55, 122, 40, 255, 226, 167, 113, 63, 26, 8, 28,   235, 246, 23, 248, 225, 29, 205, 144, 243, 180, 109, 246, 208, 70, 54, 225>>, "cbor", 1) |> CID.encode_buffer!()
      <<1, 81, 18, 32, 60, 41, 252, 52, 100, 55, 122, 40, 255, 226, 167, 113, 63, 26,
      8, 28, 235, 246, 23, 248, 225, 29, 205, 144, 243, 180, 109, 246, 208, 70, 54,
      225>>

      iex> CID.cid!( <<18, 32, 60, 41, 252, 52, 100, 55, 122, 40, 255, 226, 167, 113, 63, 26, 8, 28,   235, 246, 23, 248, 225, 29, 205, 144, 243, 180, 109, 246, 208, 70, 54, 225>>, "dag-pb", 1) |> CID.encode_buffer!()
      <<1, 112, 18, 32, 60, 41, 252, 52, 100, 55, 122, 40, 255, 226, 167, 113, 63, 26,
      8, 28, 235, 246, 23, 248, 225, 29, 205, 144, 243, 180, 109, 246, 208, 70, 54,
      225>>

  """
  def encode_buffer!(cid) do
    case encode_buffer(cid) do
      {:ok, encoded_buffer} ->
        encoded_buffer

      {:error, reason} ->
        raise ArgumentError, "unable to encode the given cid - #{inspect(reason)}"
    end
  end

  defp do_encode_buffer(%{version: 0, codec: @v0_codec, multihash: multihash}) do
    with encoded_buffer when is_binary(encoded_buffer) <- B58.encode58(multihash) do
      {:ok, encoded_buffer}
    else
      _ -> {:error, "unable to encode v0 buffer."}
    end
  end

  defp do_encode_buffer(%{version: 0}) do
    {:error, :invalid_multicodec}
  end

  defp do_encode_buffer(%{version: version, codec: codec, multihash: multihash})
       when version <= @current_version do
    with {:ok, encoded_multihash} <- Multicodec.encode(multihash, codec),
         encoded_version = Varint.LEB128.encode(version) do
      {:ok, <<encoded_version::binary, encoded_multihash::binary>>}
    end
  end

  defp do_encode_buffer(_cid) do
    {:error, :unsupported_version}
  end

  @doc """
  Creates a CID by decoding a CID encoded as a string.

  Returns an error if the encoded CID string is invalid.

  ## Examples

      iex>  CID.decode_cid("zdj7WZUkfydsNtKVZrSMzSuK6oVUj4CqpBN69q8ZRbUBdQUnC")
      {:ok, %CID{
       codec: "dag-pb",
       multihash: <<18, 32, 60, 41, 252, 52, 100, 55, 122, 40, 255, 226, 167, 113,
         63, 26, 8, 28, 235, 246, 23, 248, 225, 29, 205, 144, 243, 180, 109, 246,
         208, 70, 54, 225>>,
       version: 1
      }}

      iex> CID.decode_cid("QmSPWJYa1uQicrYWdFVHSixvrWrm8GmEDqRbtdCoNBqacG")
      {:ok, %CID{
       codec: "dag-pb",
       multihash: <<18, 32, 60, 41, 252, 52, 100, 55, 122, 40, 255, 226, 167, 113,
         63, 26, 8, 28, 235, 246, 23, 248, 225, 29, 205, 144, 243, 180, 109, 246,
         208, 70, 54, 225>>,
       version: 0
      }}

      iex> CID.decode_cid("QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR")
      {:ok, %CID{
       codec: "dag-pb",
       multihash: <<18, 32, 195, 196, 115, 62, 200, 175, 253, 6, 207, 158, 159, 245,
         15, 252, 107, 205, 46, 200, 90, 97, 112, 0, 75, 183, 9, 102, 156, 49, 222,
         148, 57, 26>>,
       version: 0
      }}

  """
  @spec decode_cid(cid_string()) :: {:ok, t()} | {:error, term()}
  def decode_cid(cid_string) when is_binary(cid_string) do
    case do_decode(cid_string) do
      {:ok, {cid, _encoding_id}} ->
        {:ok, cid}

      {:error, _reason} = err ->
        err
    end
  end

  @doc """
  Creates a CID by decoding a CID encoded as a string.

  Raises an exception if the encoded CID string is invalid.

  ## Examples

      iex> CID.decode_cid!("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      %CID{
      codec: "dag-pb",
      multihash: <<18, 32, 195, 196, 115, 62, 200, 175, 253, 6, 207, 158, 159, 245,
        15, 252, 107, 205, 46, 200, 90, 97, 112, 0, 75, 183, 9, 102, 156, 49, 222,
        148, 57, 26>>,
      version: 1
      }

      iex> CID.decode_cid!("zb2rhk6GMPQF3hfzwXTaNYFLKomMeC6UXdUt6jZKPpeVirLtV")
      %CID{
      codec: "raw",
      multihash: <<18, 32, 199, 208, 20, 137, 8, 8, 88, 197, 0, 6, 88, 54, 198, 88,
        248, 71, 166, 202, 103, 196, 134, 70, 25, 33, 43, 228, 248, 32, 14, 75, 186,
        206>>,
      version: 1
      }

      iex> CID.decode_cid!("bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy")
      %CID{
      codec: "raw",
      multihash: <<18, 32, 199, 208, 20, 137, 8, 8, 88, 197, 0, 6, 88, 54, 198, 88,
        248, 71, 166, 202, 103, 196, 134, 70, 25, 33, 43, 228, 248, 32, 14, 75, 186,
        206>>,
      version: 1
      }

  """
  @spec decode_cid!(cid_string()) :: t()
  def decode_cid!(cid_string) do
    case decode_cid(cid_string) do
      {:ok, cid} -> cid
      {:error, reason} -> raise ArgumentError, "invalid CID string - #{inspect(reason)}"
    end
  end

  @doc """
  Creates a CID by decoding a CID encoded as a string, and returns a tuple of the CID and the `encoding_id` used to encode the string with Multibase.

  Returns an error if the encoded CID string is invalid.

  ## Examples

      iex> CID.decode("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      {:ok,
      {%CID{
        codec: "dag-pb",
        multihash: <<18, 32, 195, 196, 115, 62, 200, 175, 253, 6, 207, 158, 159,
          245, 15, 252, 107, 205, 46, 200, 90, 97, 112, 0, 75, 183, 9, 102, 156, 49,
          222, 148, 57, 26>>,
        version: 1
      }, :base32_lower}}

      iex>  CID.decode("QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR")
      {:ok,
      {%CID{
        codec: "dag-pb",
        multihash: <<18, 32, 195, 196, 115, 62, 200, 175, 253, 6, 207, 158, 159,
          245, 15, 252, 107, 205, 46, 200, 90, 97, 112, 0, 75, 183, 9, 102, 156, 49,
          222, 148, 57, 26>>,
        version: 0
      }, :base58_btc}}

      iex> CID.decode("FREEPRETEZELSbafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      {:error, "unable to decode CID string"}

  """
  @spec decode(cid_string()) :: {:ok, {t(), Multibase.encoding_id()}} | {:error, term()}
  def decode(cid_string) when is_binary(cid_string) do
    do_decode(cid_string)
  end

  @doc """
  Creates a CID by decoding a CID encoded as a string, and returns a tuple of the CID and the `encoding_id` used to encode the string with Multibase.

  Raises an exception if the encoded CID string is invalid.

  ## Examples

      iex> CID.decode!("zb2rhk6GMPQF3hfzwXTaNYFLKomMeC6UXdUt6jZKPpeVirLtV")
      {%CID{
       codec: "raw",
       multihash: <<18, 32, 199, 208, 20, 137, 8, 8, 88, 197, 0, 6, 88, 54, 198, 88,
         248, 71, 166, 202, 103, 196, 134, 70, 25, 33, 43, 228, 248, 32, 14, 75,
         186, 206>>,
       version: 1
      }, :base58_btc}

      iex> CID.decode!("f015512209d8453505bdc6f269678e16b3e56c2a2948a41f2c792617cc9611ed363c95b63")
      {%CID{
       codec: "raw",
       multihash: <<18, 32, 157, 132, 83, 80, 91, 220, 111, 38, 150, 120, 225, 107,
         62, 86, 194, 162, 148, 138, 65, 242, 199, 146, 97, 124, 201, 97, 30, 211,
         99, 201, 91, 99>>,
       version: 1
      }, :base16_lower}

      iex> CID.decode!("QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n")
      {%CID{
       codec: "dag-pb",
       multihash: <<18, 32, 227, 176, 196, 66, 152, 252, 28, 20, 154, 251, 244, 200,
         153, 111, 185, 36, 39, 174, 65, 228, 100, 155, 147, 76, 164, 149, 153, 27,
         120, 82, 184, 85>>,
       version: 0
      }, :base58_btc}

  """
  @spec decode!(cid_string()) :: {t(), Multibase.encoding_id()}
  def decode!(cid_string) do
    case decode(cid_string) do
      {:ok, cid_encoding} -> cid_encoding
      {:error, reason} -> raise ArgumentError, "invalid CID string - #{inspect(reason)}"
    end
  end

  @spec do_decode(cid_string()) :: {:ok, {t(), Multibase.encoding_id()}} | {:error, term()}
  defp do_decode(data)
  # v0 decoding
  defp do_decode(<<"Qm", _rest::binary>> = data) when byte_size(data) == 46 do
    with {:ok, cid_bin} <- B58.decode58(data),
         {:ok, cid} <- decode_cid_binary(cid_bin) do
      {:ok, {cid, @v0_encoding_id}}
    end
  end

  # possible v1 decoding
  defp do_decode(data) do
    with {:ok, {decoded_bin, multibase_codec}} <- Multibase.codec_decode(data),
         # TODO: refactor - If the first decoded byte is 0x12, return an error. CIDv0 CIDs may not be multibase encoded and there will be no CIDv18 (0x12 = 18) to prevent ambiguity with decoded CIDv0s
         false <- match?(<<0x12, _::binary>>, decoded_bin),
         {:ok, cid} <- decode_cid_binary(decoded_bin) do
      {:ok, {cid, multibase_codec}}
    else
      {:error, _reason} = err -> err
      _ -> {:error, "unable to decode CID string"}
    end
  end

  @spec decode_cid_binary(binary()) :: {:ok, t()} | {:error, term()}
  defp decode_cid_binary(cid_bin)

  defp decode_cid_binary(cid_bin) when byte_size(cid_bin) == 34 do
    decode_cid_version(cid_bin, 0)
  end

  defp decode_cid_binary(cid_bin) do
    {version, payload} = Varint.LEB128.decode(cid_bin)
    decode_cid_version(payload, version)
  end

  @spec decode_cid_version(binary(), non_neg_integer()) :: {:ok, t()} | {:error, term()}
  defp decode_cid_version(cid_payload, version)

  defp decode_cid_version(cid_payload, 0) do
    {:ok, %CID{multihash: cid_payload, codec: @v0_codec, version: 0}}
  end

  defp decode_cid_version(cid_payload, 1) do
    with {:ok, {multihash, codec}} <- Multicodec.codec_decode(cid_payload) do
      {:ok, %CID{multihash: multihash, codec: codec, version: 1}}
    end
  end

  defp decode_cid_version(_cid_payload, version) when version > @current_version do
    # raise ArgumentError, "CID version #{inspect version} is reserved and not yet supported."
    {:error, :unsupported_version}
  end

  defp decode_cid_version(_cid_payload, _version) do
    # raise ArgumentError, "CID is malformed"
    {:error, :invalid_cid}
  end

  @doc """
  Converts a CID to a given destination version.

  Returns an error if the conversion is not possible. Conversion to a v0 CID is only possible if the codec is `dag-pb`.

  ## Examples

      iex> CID.to_version(%CID{codec: "dag-pb", multihash: <<18, 32, 227, 176, 196, 66, 152, 252, 28, 20, 154, 251, 244, 200, 153, 111, 185, 36, 39, 174, 65, 228, 100, 155, 147, 76, 164, 149, 153, 27, 120, 82, 184, 85>>, version: 0}, 1)
      {:ok,
        %CID{
         codec: "dag-pb",
         multihash: <<18, 32, 227, 176, 196, 66, 152, 252, 28, 20, 154, 251, 244, 200,
           153, 111, 185, 36, 39, 174, 65, 228, 100, 155, 147, 76, 164, 149, 153, 27,
           120, 82, 184, 85>>,
         version: 1
        }}

        iex> CID.decode_cid!("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi") |> CID.to_version(1)
        {:ok,
        %CID{
         codec: "dag-pb",
         multihash: <<18, 32, 195, 196, 115, 62, 200, 175, 253, 6, 207, 158, 159, 245,
           15, 252, 107, 205, 46, 200, 90, 97, 112, 0, 75, 183, 9, 102, 156, 49, 222,
           148, 57, 26>>,
         version: 1
        }}

        iex> CID.to_version(%CID{codec: "raw", multihash: <<18, 32, 157, 132, 83, 80, 91, 220, 111, 38, 150, 120, 225, 107, 62, 86, 194, 162, 148, 138, 65, 242, 199, 146, 97, 124, 201, 97, 30, 211, 99, 201, 91, 99>>, version: 1}, 0)
        {:error, :unsupported_conversion}

  """
  def to_version(cid, destination_version)
      when is_map(cid) and is_integer(destination_version) and
             destination_version <= @current_version do
    convert_version(cid, destination_version)
  end

  defp convert_version(%{version: version} = cid, destination_version)
       when version == destination_version do
    {:ok, cid}
  end

  defp convert_version(%{codec: codec}, 0) when codec != @v0_codec do
    {:error, :unsupported_conversion}
  end

  defp convert_version(cid, destination_version) do
    {:ok, %{cid | version: destination_version}}
  end

  @doc ~S"""
  Returns a human readable CID

  ## Overview

  It is advantageous to have a human readable description of a CID, solely for the purposes of debugging and explanation. We can easily transform a CID to a "Human Readable CID" as follows:

  ```
  <hr-cid> ::= <hr-mbc> "-" <hr-cid-version> "-" <hr-mc> "-" <hr-mh>
  ```
  Where each sub-component is represented with its own human-readable form:

  - `<hr-mbc>` is a human-readable multibase code (eg `base58btc`)
  - `<hr-cid-version>` is the string `cidv#` (eg `cidv1` or `cidv2`)
  - `<hr-mc>` is a human-readable multicodec code (eg `cbor`)
  - `<hr-mh>` is a human-readable multihash (eg `sha2-256-256-abcdef0123456789...`)

  ## Examples

      iex> CID.humanize("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      {:ok,
      "base32_lower - CIDv1 - dag-pb - sha2_256 - c3c4733ec8affd06cf9e9ff50ffc6bcd2ec85a6170004bb709669c31de94391a"}

      iex> CID.humanize("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi", "-")
      {:ok,
      "base32_lower-CIDv1-dag-pb-sha2_256-c3c4733ec8affd06cf9e9ff50ffc6bcd2ec85a6170004bb709669c31de94391a"}

      iex> CID.humanize("f015512209d8453505bdc6f269678e16b3e56c2a2948a41f2c792617cc9611ed363c95b63", "::")
      {:ok,
      "base16_lower::CIDv1::raw::sha2_256::9d8453505bdc6f269678e16b3e56c2a2948a41f2c792617cc9611ed363c95b63"}

      iex> CID.humanize("super delicious rolls")
      {:error, "unable to decode CID string"}

  """
  @spec humanize(cid_string(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def humanize(cid_string, separator \\ " - ")
      when is_binary(cid_string) and is_binary(separator) do
    with true <- String.printable?(separator),
         {:ok, {%{multihash: multihash, codec: codec, version: version}, encoding_id}} <-
           do_decode(cid_string),
         {:ok, %{digest: digest, name: hash_name}} <- Multihash.decode(multihash) do
      hex_digest = Base.encode16(digest, case: :lower)

      {:ok,
       [encoding_id, Enum.join(["CIDv", version]), codec, hash_name, hex_digest]
       |> Enum.join(separator)}
    else
      {:error, _reason} = err -> err
      false -> {:error, "invalid separator."}
      _ -> {:error, "unable to decode CID string"}
    end
  end

  @doc """
  Checks if a given CID string is a valid encoded CID.

  ## Examples

      iex> CID.cid?("uAakCERTEGXXR2uHMabFq2IkrjHcWToTKOQ")
      true

      iex> CID.cid?("sweep the leg")
      false

      iex> CID.cid?("f015512209d8453505bdc6f269678e16b3e56c2a2948a41f2c792617cc9611ed363c95b63")
      true

      iex> CID.cid?("$f015512209d8453505bdc6f269678e16b3e56c2a2948a41f2c792617cc9611ed363c95b63")
      false

  """
  @spec cid?(cid_string()) :: boolean()
  def cid?(cid_string) do
    case decode_cid(cid_string) do
      {:ok, _cid} -> true
      _ -> false
    end
  end

  @doc """
  Creates a new CID by hashing the given data using the specified hash algorithm and codec.

  ## Parameters

  - `hash_algorithm`: The hash algorithm to use (e.g., `:sha2_256`).
  - `data`: The binary data to hash.
  - `codec`: The codec to use for the CID (e.g., `"dag-cbor"`).

  ## Returns

  - `{:ok, CID.t()}` on success.
  - `{:error, reason}` on failure.
  """
  @spec create_cid(atom(), binary(), Multicodec.multi_codec()) :: {:ok, t()} | {:error, term()}
  def create_cid(hash_algorithm, data, codec \\ @v0_codec) when is_atom(hash_algorithm) and is_binary(data) do
    with {:ok, multihash} <- Multihash.encode(hash_algorithm, data),
        {:ok, cid} <- cid(multihash, codec, @current_version) do
      {:ok, cid}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Alias for `create_cid/3`.
  """
  @spec new(atom(), binary()) :: {:ok, t()} | {:error, term()}
  def new(hash_algorithm, data) do
    create_cid(hash_algorithm, data)
  end


  defimpl String.Chars, for: CID do
    def to_string(cid), do: CID.encode!(cid, :base32_lower)
  end

  @spec to_string(CID.t()) :: String.t()
  def to_string(%CID{} = cid) do
    encode!(cid, :base32_lower)
  end

  @doc """
  Parses a CID string into a CID struct.

  Returns `{:ok, CID.t()}` on success, or `{:error, reason}` on failure.
  """
  @spec from_string(String.t()) :: {:ok, t()} | {:error, term()}
  def from_string(cid_string) when is_binary(cid_string) do
    decode_cid(cid_string)
  end

  @doc """
  Parses a CID string into a CID struct.

  Raises an exception if the CID string is invalid.
  """
  @spec from_string!(String.t()) :: t()
  def from_string!(cid_string) do
    decode_cid!(cid_string)
  end
end
