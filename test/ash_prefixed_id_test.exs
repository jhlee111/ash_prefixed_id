defmodule AshPrefixedIdTest do
  use ExUnit.Case, async: true

  alias AshPrefixedId
  alias AshPrefixedId.Test.Domain
  alias AshPrefixedId.Test.Resources.Comment
  alias AshPrefixedId.Test.Resources.Post
  alias AshPrefixedId.Test.Resources.Unrelated

  @valid_id "user_CWzLBdFy2f1XhrtesFferY"
  @valid_uuid "5d446d08-df6a-404d-a1e5-decc78429b3d"

  test "it replaces the primary key with an object id" do
    assert [pk] = Ash.Resource.Info.primary_key(Post)
    attr = Ash.Resource.Info.attribute(Post, pk)
    assert attr.name == :id
    assert attr.type == Post.ObjectId
  end

  test "relationships" do
    post =
      Post
      |> Ash.Changeset.for_create(:create, %{title: "Designing APIs for humans"})
      |> Ash.create!()

    assert "post_" <> id = post.id
    assert AshPrefixedId.find_resource_for_id([Domain], post.id) == Post

    assert_raise Ash.Error.Invalid, ~r/incorrect object prefix/, fn ->
      Comment
      |> Ash.Changeset.for_create(:create, %{
        post_id: "florb_#{id}",
        body: "I like this"
      })
      |> Ash.create!()
    end

    comment =
      Comment
      |> Ash.Changeset.for_create(:create, %{
        post_id: post.id,
        body: "I like this"
      })
      |> Ash.create!()

    assert "c_" <> _ = comment.id
  end

  test "BelongsToAttribute auto-creates FK with ObjectId type" do
    # Comment.post_id should be auto-created as Post.ObjectId
    # (no manual attribute_type: needed)
    attr = Ash.Resource.Info.attribute(Comment, :post_id)
    assert attr != nil
    assert attr.type == Post.ObjectId
  end

  test "find_resource_for_prefix/2" do
    assert AshPrefixedId.find_resource_for_prefix([Domain], "post") == Post
    assert AshPrefixedId.find_resource_for_prefix([Domain], "florb") == nil
  end

  test "find_resource_for_id/2" do
    assert AshPrefixedId.find_resource_for_id([Domain], "post_CWzLBdFy2f1XhrtesFferY") == Post
    assert AshPrefixedId.find_resource_for_id([Domain], "florb_CWzLBdFy2f1XhrtesFferY") == nil
  end

  test "map_prefixes_to_resources/1" do
    assert %{"post" => [Post], "c" => [Unrelated, Comment]} =
             AshPrefixedId.map_prefixes_to_resources([Domain])
  end

  test "find_duplicate_prefixes" do
    assert %{"c" => [Unrelated, Comment]} == AshPrefixedId.find_duplicate_prefixes([Domain])
  end

  describe "to_uuid/1 (non-bang, external-boundary)" do
    test "decodes a valid prefixed ID to a 16-byte binary" do
      assert {:ok, bin} = AshPrefixedId.to_uuid(@valid_id)
      assert byte_size(bin) == 16
    end

    test "returns {:error, :invalid_prefixed_id} for malformed input" do
      assert {:error, :invalid_prefixed_id} = AshPrefixedId.to_uuid("garbage")
      assert {:error, :invalid_prefixed_id} = AshPrefixedId.to_uuid("user_2")
    end
  end

  describe "to_uuid!/1 (bang, Ash-internal default)" do
    test "returns the raw 16-byte binary" do
      assert <<_::128>> = AshPrefixedId.to_uuid!(@valid_id)
    end

    test "raises ArgumentError for malformed input" do
      assert_raise ArgumentError, fn -> AshPrefixedId.to_uuid!("garbage") end
      assert_raise ArgumentError, fn -> AshPrefixedId.to_uuid!("user_2") end
    end
  end

  describe "to_uuid_string/1 (non-bang, external-boundary)" do
    test "decodes a valid prefixed ID to a dashed UUID string" do
      assert {:ok, @valid_uuid} = AshPrefixedId.to_uuid_string(@valid_id)
    end

    test "returns {:error, :invalid_prefixed_id} for malformed input" do
      assert {:error, :invalid_prefixed_id} = AshPrefixedId.to_uuid_string("garbage")
    end
  end

  describe "to_uuid_string!/1 (bang, Ash-internal default)" do
    test "returns the dashed UUID string" do
      assert @valid_uuid == AshPrefixedId.to_uuid_string!(@valid_id)
    end

    test "raises ArgumentError (not MatchError) for malformed input" do
      assert_raise ArgumentError, fn -> AshPrefixedId.to_uuid_string!("garbage") end
    end
  end

  describe "to_prefixed_id/2" do
    test "encodes a uuid binary with a string prefix" do
      {:ok, bin} = AshPrefixedId.to_uuid(@valid_id)
      assert @valid_id == AshPrefixedId.to_prefixed_id(bin, "user")
    end

    test "resolves the prefix from a resource module" do
      bin = Ecto.UUID.bingenerate()
      assert "post_" <> _ = AshPrefixedId.to_prefixed_id(bin, Post)
    end

    test "resource overload round-trips through the resource's ObjectId" do
      bin = Ecto.UUID.bingenerate()
      encoded = AshPrefixedId.to_prefixed_id(bin, Post)
      assert {:ok, ^bin} = AshPrefixedId.to_uuid(encoded)
    end
  end

  test "public decode_object_id/1 is removed in favor of to_uuid_string/1" do
    refute function_exported?(AshPrefixedId, :decode_object_id, 1)
  end

  describe "non-base58 characters (erl_base58 raises internally)" do
    # '0', 'O', 'I', 'l' sit OUTSIDE the base58 alphabet, and erl_base58's
    # base58_to_binary RAISES ArithmeticError (`:error * 58`) on them
    # instead of returning an error. This is exactly what a public URL
    # delivers (gs_net /expo/e/:slug/:event_id, 2026-07-18): every
    # malformed input must come back as a tagged error, never a crash.
    test "to_uuid/1 returns a tagged error, not a raise" do
      assert {:error, :invalid_prefixed_id} =
               AshPrefixedId.to_uuid("user_00000000000000000000000000")

      assert {:error, :invalid_prefixed_id} = AshPrefixedId.to_uuid("user_OIl0")
    end

    test "to_uuid_string!/1 raises ArgumentError, not ArithmeticError" do
      assert_raise ArgumentError, fn ->
        AshPrefixedId.to_uuid_string!("user_0")
      end
    end

    test "the cast path (Type.decode_object_id/2) returns a tagged error" do
      assert {:error, :invalid_prefixed_id} =
               AshPrefixedId.Type.decode_object_id("user_0IlO", "user")
    end

    test "an empty slug is an error, not a crash" do
      assert {:error, :invalid_prefixed_id} = AshPrefixedId.to_uuid("user_")
    end
  end
end
