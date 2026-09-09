require "test_helper"

class Things::MergePlanTest < ActiveSupport::TestCase
  setup do
    @target = things(:keyboard)
    @source = things(:router)
  end

  test "treats differing values as a conflict" do
    assert_includes conflict_names, "name"
    assert_includes conflict_names, "description"
  end

  test "treats a value the target is missing as carried over" do
    assert_includes carried_over_names, "owner"
    assert_includes carried_over_names, "ip_address"
    assert_not_includes conflict_names, "owner"
  end

  test "leaves matching values alone" do
    @source.update!(name: @target.name)

    assert_not_includes conflict_names, "name"
    assert_not_includes carried_over_names, "name"
  end

  test "treats a differing public flag as a conflict" do
    assert_includes conflict_names, "public_access"
  end

  test "treats a matching public flag as no conflict" do
    @source.update!(public_access: true)

    assert_not_includes conflict_names, "public_access"
  end

  test "compares standard links field by field" do
    @source.links.find_by(link_type: :where).update!(url: "https://geowiki.example.com/locations/rack-9")
    @target.links.create!(link_type: :where, url: "https://geowiki.example.com/locations/desk-1")

    assert_includes conflict_names, "link_where_url"
    assert_includes carried_over_names, "link_asset_url"
  end

  test "defaults a conflict to the target's value and a gap to the source's" do
    defaults = plan.defaults

    assert_equal @target.name, defaults["name"]
    assert_equal @source.owner, defaults["owner"]
  end

  test "resolve accepts a submitted value for a conflicting field" do
    resolved = plan.resolve("name" => "Merged name")

    assert_equal "Merged name", resolved[:attributes]["name"]
  end

  test "resolve ignores submitted values for fields that do not conflict" do
    resolved = plan.resolve("owner" => "someone else")

    assert_equal @source.owner, resolved[:attributes]["owner"]
  end

  test "resolve groups standard link values by link type" do
    resolved = plan.resolve

    assert_equal thing_links(:router_asset).url, resolved[:links]["asset"]["url"]
    assert_equal "Front rack label", resolved[:links]["asset"]["note"]
    assert_equal thing_links(:keyboard_wiki).url, resolved[:links]["wiki"]["url"]
  end

  test "reports what is carried over without asking" do
    dongle = Thing.create!(name: "Dongle")
    @source.thing_relationships.create!(related_thing: dongle)
    attach_photo(@source)

    assert_equal 1, plan.photo_count
    assert_equal 1, plan.custom_links.size
    assert_equal [ dongle.id ], plan.relationship_additions.map(&:related_thing_id)
    assert_equal 2, plan.integration_device_count
  end

  test "does not count a relationship to the target itself" do
    assert_empty plan.relationship_additions
  end

  test "reports the retired key and slug" do
    @source.update!(slug: "main-router")

    assert_equal @source.key, plan.retired_key
    assert_equal "main-router", plan.retired_slug
  end

  test "does not report a retired slug the target keeps" do
    assert_nil plan.retired_slug
  end

  test "does not build blank links on either thing" do
    plan.groups

    assert_nil @target.links.detect { |link| link.new_record? }
    assert_nil @source.links.detect { |link| link.new_record? }
  end

  private

  def plan
    @plan ||= Things::MergePlan.new(target: @target, source: @source)
  end

  def conflict_names
    plan.conflicts.map(&:name)
  end

  def carried_over_names
    plan.carried_over_fields.map(&:name)
  end
end
