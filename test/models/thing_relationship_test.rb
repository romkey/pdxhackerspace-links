require "test_helper"

class ThingRelationshipTest < ActiveSupport::TestCase
  test "requires distinct things" do
    thing = things(:keyboard)
    relationship = ThingRelationship.new(thing: thing, related_thing: thing)

    assert_not relationship.valid?
    assert_includes relationship.errors[:related_thing], "can't be the same thing"
  end

  test "rejects duplicate pairs" do
    existing = thing_relationships(:keyboard_router)
    duplicate = ThingRelationship.new(
      thing: existing.thing,
      related_thing: existing.related_thing
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:related_thing_id], "has already been taken"
  end

  test "creates inverse relationship on create" do
    mouse = Thing.create!(name: "Mouse")
    dongle = Thing.create!(name: "Dongle")

    ThingRelationship.create!(thing: mouse, related_thing: dongle, note: "USB receiver")

    assert mouse.related_things.include?(dongle)
    assert dongle.related_things.include?(mouse)
    assert_equal "USB receiver", dongle.thing_relationships.find_by(related_thing: mouse).note
  end

  test "syncs note to inverse on update" do
    relationship = thing_relationships(:keyboard_router)
    relationship.update!(note: "Updated note")

    inverse = thing_relationships(:router_keyboard).reload
    assert_equal "Updated note", inverse.note
  end

  test "destroys inverse on destroy" do
    relationship = thing_relationships(:keyboard_router)
    keyboard = relationship.thing
    router = relationship.related_thing

    relationship.destroy!

    assert_not keyboard.related_things.include?(router)
    assert_not router.related_things.include?(keyboard)
  end

  test "relating things marks both as updated" do
    keyboard = things(:keyboard)
    router = things(:router)
    ThingRelationship.where(thing: [ keyboard, router ]).delete_all
    Thing.where(id: [ keyboard.id, router.id ]).update_all(updated_at: 1.day.ago)

    ThingRelationship.create!(thing: keyboard, related_thing: router, note: "pair")

    assert_operator keyboard.reload.updated_at, :>, 1.hour.ago
    assert_operator router.reload.updated_at, :>, 1.hour.ago
  end
end
