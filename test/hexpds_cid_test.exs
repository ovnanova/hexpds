defmodule CIDTest do
  # Taken from nocursor/ex-cid

  alias Hexpds.{CID, Multicodec}
  use ExUnit.Case, async: true
  doctest CID
  require Multibase

  # TODO: better test setup to include more re-used data or scope the data, but the data is pretty simple so.......maybe not
  setup_all do
    digest = :crypto.hash(:sha256, "hello world")
    {:ok, multihash} = Multihash.encode(:sha2_256, digest)
    %{multihash: multihash}
  end

  test "creates a v0 CID", %{multihash: multihash} do
    codec = "dag-pb"
    cid = %CID{version: 0, multihash: multihash, codec: codec}
    assert CID.cid(multihash, codec, 0) == {:ok, cid}
    assert CID.cid!(multihash, codec, 0) == cid
  end

  test "v0 CIDs cannot be created for other codecs", %{multihash: multihash} do
    codec = "dag-json"
    assert {:error, _reason} = CID.cid(multihash, codec, 0)
    assert_raise ArgumentError, fn -> CID.cid!(multihash, codec, 0) end
  end

  test "creates a v1 CID for all Multicodecs", %{multihash: multihash} do
    for codec <- Multicodec.codecs() do
      cid = %CID{version: 1, multihash: multihash, codec: codec}
      assert CID.cid(multihash, codec, 1) == {:ok, cid}
      assert CID.cid(multihash, codec) == {:ok, cid}
      assert CID.cid!(multihash, codec, 1) == cid
      assert CID.cid!(multihash, codec) == cid
    end
  end

  test "errors when trying to create CIDs with codecs that don't exist", %{multihash: multihash} do
    codec = "banana fishbones"
    assert {:error, _reason} = CID.cid(multihash, codec, 0)
    assert_raise ArgumentError, fn -> CID.cid!(multihash, codec, 0) end
    assert {:error, _reason} = CID.cid(multihash, codec, 1)
    assert_raise ArgumentError, fn -> CID.cid!(multihash, codec, 1) end
  end

  test "errors when trying to create CIDs with versions that don't exist", %{multihash: multihash} do
    codec = "dag-pb"
    assert {:error, _reason} = CID.cid(multihash, codec, -1)
    assert_raise ArgumentError, fn -> CID.cid!(multihash, codec, 93_349_329_439) end
  end

  test "errors when trying to create a CID v1 with an invalid multihash" do
    codec = "dag-pb"

    assert {:error, _reason} = CID.cid("cookie palace 5000", codec, 0)
    assert_raise ArgumentError, fn -> CID.cid!("perturbed space chicken", codec, 0) end
    assert {:error, _reason} = CID.cid(<<>>, codec, 0)
    assert_raise ArgumentError, fn -> CID.cid!(<<>>, codec, 0) end
  end

  test "encodes a v0 CID for base 58 btc", %{multihash: multihash} do
    cid = CID.cid!(multihash, "dag-pb", 0)
    assert CID.encode(cid, :base58_btc) == {:ok, "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"}
    assert CID.encode(cid) == {:ok, "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"}
    assert CID.encode!(cid, :base58_btc) == "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"
    assert CID.encode!(cid) == "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"
  end

  test "encodes a v1 CID for base 58 btc", %{multihash: multihash} do
    cid = CID.cid!(multihash, "dag-pb", 1)

    assert CID.encode(cid, :base58_btc) ==
             {:ok, "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz"}

    assert CID.encode(cid) == {:ok, "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz"}
    assert CID.encode!(cid, :base58_btc) == "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz"
    assert CID.encode!(cid) == "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz"
  end

  test "encodes a v1 CID for all Multibase encodings", %{multihash: multihash} do
    cid = CID.cid!(multihash, "dag-pb", 1)

    for encoding_id <- Multibase.encodings() do
      assert {:ok, _encoded_cid} = CID.encode(cid, encoding_id)
      encoded_cid = CID.encode!(cid, encoding_id)
      assert is_binary(encoded_cid) == true
      assert encoded_cid != <<0>>
    end
  end

  test "errors encoding an invalid CID", %{multihash: multihash} do
    codec = "dag-pb"

    assert {:error, _reason} =
             CID.encode(%CID{version: 435_843_589_348_594, multihash: multihash, codec: codec})

    assert {:error, _reason} =
             CID.encode(%CID{version: 1, multihash: multihash, codec: "club spatula"})

    assert {:error, _reason} =
             CID.encode(%CID{version: 0, multihash: multihash, codec: "club spatula"})

    assert_raise ArgumentError, fn ->
      CID.encode!(%CID{version: 6_666_666, multihash: multihash, codec: codec})
    end

    assert_raise ArgumentError, fn ->
      CID.encode!(%CID{version: 1, multihash: multihash, codec: "club spatula"})
    end

    assert_raise ArgumentError, fn ->
      CID.encode!(%CID{version: 0, multihash: multihash, codec: "club spatula"})
    end

    # TODO: not sure if we care if someone does something this dumb
    # assert {:error, _reason } = CID.encode(%CID{version: 0, multihash: "feathery beast", codec: codec})
  end

  test "decodes a v0 CID string", %{multihash: multihash} do
    cid = CID.cid!(multihash, "dag-pb", 0)
    cid_string = "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"
    assert CID.decode_cid(cid_string) == {:ok, cid}
    assert CID.decode_cid!(cid_string) == cid
  end

  test "decodes a v0 CID string with its encoding id", %{multihash: multihash} do
    cid = CID.cid!(multihash, "dag-pb", 0)
    cid_string = "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"
    assert CID.decode(cid_string) == {:ok, {cid, :base58_btc}}
    assert CID.decode!(cid_string) == {cid, :base58_btc}
  end

  test "decodes a v1 CID string", %{multihash: multihash} do
    cid = CID.cid!(multihash, "dag-pb", 1)
    cid_string = "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz"
    assert CID.decode_cid(cid_string) == {:ok, cid}
    assert CID.decode_cid!(cid_string) == cid
  end

  test "decodes a v1 CID string with its encoding id", %{multihash: multihash} do
    cid = CID.cid!(multihash, "dag-pb", 1)
    cid_string = "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz"
    assert CID.decode(cid_string) == {:ok, {cid, :base58_btc}}
    assert CID.decode!(cid_string) == {cid, :base58_btc}
  end

  test "errors decoding invalid CIDs" do
    assert {:error, _reason} = CID.decode(<<>>)
    assert {:error, _reason} = CID.decode("pudding should be drunk not eaten")
    assert {:error, _reason} = CID.decode("Zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz")

    assert {:error, _reason} =
             CID.decode(<<0, "Zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz">>)

    assert_raise ArgumentError, fn -> CID.decode!(<<>>) end
    assert_raise ArgumentError, fn -> CID.decode!("shout for some sprouts") end

    assert_raise ArgumentError, fn ->
      CID.decode!("Zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz")
    end

    assert_raise ArgumentError, fn ->
      CID.decode!(<<0, "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz">>)
    end
  end

  test "errors cid decoding invalid CIDs" do
    assert {:error, _reason} = CID.decode_cid(<<>>)
    assert {:error, _reason} = CID.decode_cid("Zam, but not Shazam")
    assert {:error, _reason} = CID.decode_cid("Zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz")

    assert {:error, _reason} =
             CID.decode_cid(<<0, "Zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz">>)

    assert_raise ArgumentError, fn -> CID.decode_cid!(<<>>) end
    assert_raise ArgumentError, fn -> CID.decode_cid!("softest pretzels in the city") end

    assert_raise ArgumentError, fn ->
      CID.decode_cid!("Zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz")
    end

    assert_raise ArgumentError, fn ->
      CID.decode_cid!(<<0, "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz">>)
    end
  end

  test "transparently encodes and decodes v1 CIDs for all Multibase encodings and Multicodec codecs",
       %{multihash: multihash} do
    Multicodec.codecs()
    |> Task.async_stream(fn codec ->
      tasks =
        for encoding_id <- Multibase.encodings() do
          cid = CID.cid!(multihash, codec, 1)

          Task.async(fn ->
            {:ok, cid_string} = CID.encode(cid, encoding_id)
            assert CID.decode_cid(cid_string) == {:ok, cid}
            assert CID.decode(cid_string) == {:ok, {cid, encoding_id}}
            assert CID.encode!(cid, encoding_id) |> CID.decode_cid!() == cid
            assert CID.encode!(cid, encoding_id) |> CID.decode!() == {cid, encoding_id}
          end)
        end

      Enum.map(tasks, &Task.await/1)
    end)
  end

  test "encodes a CID v0 buffer", %{multihash: multihash} do
    cid = CID.cid!(multihash, "dag-pb", 0)
    assert CID.encode_buffer(cid) == {:ok, "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"}
  end

  test "encodes a CID v1 buffer", %{multihash: multihash} do
    cid = CID.cid!(multihash, "dag-pb", 1)

    assert CID.encode_buffer(cid) ==
             {:ok,
              <<1, 112, 18, 32, 185, 77, 39, 185, 147, 77, 62, 8, 165, 46, 82, 215, 218, 125, 171,
                250, 196, 132, 239, 227, 122, 83, 128, 238, 144, 136, 247, 172, 226, 239, 205,
                233>>}
  end

  test "encodes a CID v1 buffer for all codecs", %{multihash: multihash} do
    for codec <- Multicodec.codecs() do
      cid = CID.cid!(multihash, codec, 1)
      assert {:ok, _buffer} = CID.encode_buffer(cid)
      encoded_buffer = CID.encode_buffer!(cid)
      assert is_binary(encoded_buffer)
      assert encoded_buffer != <<0>>
    end
  end

  test "humanizes a v0 CID string" do
    cid_string = "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"

    assert CID.humanize(cid_string) ==
             {:ok,
              "base58_btc - CIDv0 - dag-pb - sha2_256 - b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"}
  end

  test "humanizes a v0 CID string with a custom separator" do
    cid_string = "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"

    assert CID.humanize(cid_string, "-") ==
             {:ok,
              "base58_btc-CIDv0-dag-pb-sha2_256-b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"}

    assert CID.humanize(cid_string, "=^_^=") ==
             {:ok,
              "base58_btc=^_^=CIDv0=^_^=dag-pb=^_^=sha2_256=^_^=b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"}
  end

  test "humanizes a v1 CID string" do
    cid_string = "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz"

    humanized_string =
      "base58_btc - CIDv1 - dag-pb - sha2_256 - b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"

    assert CID.humanize(cid_string) == {:ok, humanized_string}
  end

  test "humanizes a v1 CID string with a custom separator" do
    cid_string = "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz"

    humanized_string =
      "base58_btc-CIDv1-dag-pb-sha2_256-b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"

    assert CID.humanize(cid_string, "-") == {:ok, humanized_string}

    assert CID.humanize(cid_string, "><(((('>") ==
             {:ok,
              "base58_btc><(((('>CIDv1><(((('>dag-pb><(((('>sha2_256><(((('>b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"}
  end

  test "checks if a CID v0 string is encoded" do
    cid_string = "QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"
    assert CID.cid?(cid_string) == true
    assert CID.cid?("super super super cats") == false
  end

  test "checks if a CID v1 string is encoded" do
    cid_string = "zdj7WhuEjrB52m1BisYCtmjH1hSKa7yZ3jEZ9JcXaFRD51wVz"
    assert CID.cid?(cid_string) == true
    assert CID.cid?("wwwwwwwwhat? what did you put in those pants of yours?") == false
  end

  test "CID v0 can be converted to v1", %{multihash: multihash} do
    cid_v1 = CID.cid!(multihash, "dag-pb", 1)
    cid_v0 = CID.cid!(multihash, "dag-pb", 0)
    assert CID.to_version(cid_v0, 1) == {:ok, cid_v1}
  end

  test "CID v1 can be converted to v0 for the default codec", %{multihash: multihash} do
    cid_v1 = CID.cid!(multihash, "dag-pb", 1)
    cid_v0 = CID.cid!(multihash, "dag-pb", 0)
    assert CID.to_version(cid_v1, 0) == {:ok, cid_v0}
  end

  test "CID v1 cannot be converted to v0 for codecs other than the default codec", %{
    multihash: multihash
  } do
    cid_v1 = CID.cid!(multihash, "dag-json", 1)
    assert {:error, _reason} = CID.to_version(cid_v1, 0)
  end

  test "Conversions to the same CID version are effecitvely a noop", %{multihash: multihash} do
    cid_v1 = CID.cid!(multihash, "dag-pb", 1)
    cid_v0 = CID.cid!(multihash, "dag-pb", 0)
    assert CID.to_version(cid_v1, 1) == {:ok, cid_v1}
    assert CID.to_version(cid_v1, 0) == {:ok, cid_v0}
  end
end
