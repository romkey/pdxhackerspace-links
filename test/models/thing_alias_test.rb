require "test_helper"

class ThingAliasTest < ActiveSupport::TestCase
  test "requires a key or a slug" do
    thing_alias = ThingAlias.new(thing: things(:router))

    assert_not thing_alias.valid?
    assert_includes thing_alias.errors[:base], "needs a key or a slug"
  end

  test "accepts a key on its own" do
    assert ThingAlias.new(thing: things(:router), key: "retkey12").valid?
  end

  test "accepts a slug on its own" do
    assert ThingAlias.new(thing: things(:router), slug: "retired-router").valid?
  end

  test "rejects a key held by a live thing" do
    thing_alias = ThingAlias.new(thing: things(:router), key: things(:keyboard).key)

    assert_not thing_alias.valid?
    assert_includes thing_alias.errors[:key], "is already used by a thing"
  end

  test "rejects a slug held by a live thing" do
    thing_alias = ThingAlias.new(thing: things(:router), slug: things(:keyboard).slug)

    assert_not thing_alias.valid?
    assert_includes thing_alias.errors[:slug], "is already used by a thing"
  end

  test "rejects a key already retired" do
    thing_alias = ThingAlias.new(thing: things(:router), key: thing_aliases(:retired_keyboard).key)

    assert_not thing_alias.valid?
    assert_includes thing_alias.errors[:key], "has already been taken"
  end

  test "rejects a slug already retired" do
    thing_alias = ThingAlias.new(thing: things(:router), slug: thing_aliases(:retired_keyboard).slug)

    assert_not thing_alias.valid?
    assert_includes thing_alias.errors[:slug], "has already been taken"
  end

  test "rejects a key that is not in key format" do
    thing_alias = ThingAlias.new(thing: things(:router), key: "12345678")

    assert_not thing_alias.valid?
    assert_includes thing_alias.errors[:key], "is invalid"
  end

  test "normalizes case and whitespace" do
    thing_alias = ThingAlias.create!(thing: things(:router), key: "  RETKEY12 ", slug: " Retired-Router ")

    assert_equal "retkey12", thing_alias.key
    assert_equal "retired-router", thing_alias.slug
  end

  test "is removed when its thing is deleted" do
    assert_difference -> { ThingAlias.count }, -1 do
      things(:keyboard).destroy!
    end
  end
end
