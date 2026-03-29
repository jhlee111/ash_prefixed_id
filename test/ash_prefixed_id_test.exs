defmodule AshPrefixedIdTest do
  use ExUnit.Case, async: true

  alias AshPrefixedId
  alias AshPrefixedId.Test.Domain
  alias AshPrefixedId.Test.Resources.Comment
  alias AshPrefixedId.Test.Resources.Post
  alias AshPrefixedId.Test.Resources.Unrelated

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
end
