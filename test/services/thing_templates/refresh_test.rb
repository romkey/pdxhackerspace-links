require "test_helper"

module ThingTemplates
  class RefreshTest < ActiveSupport::TestCase
    setup do
      travel_to Time.zone.local(2026, 10, 1, 12)
      @template = ThingTemplate.create!(
        name: "Lamp",
        thing_name: "Lamp",
        owner: "romkey",
        manufacturer: "Acme",
        model: "L1",
        notes: "Bulb is E26",
        links: [
          { "link_type" => "wiki", "url" => "https://wiki.example.com/lamp", "note" => "Setup" },
          { "link_type" => "custom", "title" => "Manual", "url" => "https://example.com/lamp-v1", "note" => nil }
        ]
      )
      travel 1.hour
      @thing = @template.build_thing
      @thing.save!
      travel 1.hour
    end

    teardown { travel_back }

    test "updates values the thing still has from the template" do
      @template.update!(model: "L2", links: [
        { "link_type" => "wiki", "url" => "https://wiki.example.com/lamp2", "note" => "Setup" },
        { "link_type" => "custom", "title" => "Manual", "url" => "https://example.com/lamp-v2", "note" => nil }
      ])

      result = Refresh.call(template: @template)

      @thing.reload
      assert_equal [ @thing ], result.updated
      assert_equal "L2", @thing.model
      assert_equal "https://wiki.example.com/lamp2", @thing.link_for("wiki").url
      assert_equal "https://example.com/lamp-v2", @thing.custom_links.sole.url
    end

    test "keeps values changed on the thing" do
      @thing.update!(model: "L1 custom", owner: "someone")
      @template.update!(model: "L2", owner: "team")

      Refresh.call(template: @template)

      @thing.reload
      assert_equal "L1 custom", @thing.model
      assert_equal "someone", @thing.owner
    end

    test "fills in blank fields and missing links" do
      @thing.update!(notes: "", manufacturer: nil,
                     links_attributes: [ { id: @thing.custom_links.sole.id, _destroy: "1" } ])
      @template.update!(description: "A lamp")

      Refresh.call(template: @template)

      @thing.reload
      assert_equal "Bulb is E26", @thing.notes
      assert_equal "Acme", @thing.manufacturer
      assert_equal "A lamp", @thing.description
      assert_equal "https://example.com/lamp-v1", @thing.custom_links.sole.url
    end

    test "adds links the template gained" do
      @template.update!(links: @template.links + [ { "link_type" => "slack", "url" => "https://slack.example.com/lamp", "note" => nil } ])

      Refresh.call(template: @template)

      assert_equal "https://slack.example.com/lamp", @thing.reload.link_for("slack").url
    end

    test "follows the template through several versions" do
      @template.update!(model: "L2")
      travel 1.hour
      @template.update!(model: "L3")

      Refresh.call(template: @template)

      assert_equal "L3", @thing.reload.model
    end

    test "ignores template values from before the thing was made" do
      @template.update!(model: "L2")
      Refresh.call(template: @template)
      travel 1.hour
      later = @template.build_thing
      later.save!
      later.update!(model: "L1")
      travel 1.hour
      @template.update!(model: "L3")

      Refresh.call(template: @template)

      assert_equal "L3", @thing.reload.model
      assert_equal "L1", later.reload.model
    end

    test "journals the refresh on the thing and the template" do
      @template.update!(model: "L2")

      Refresh.call(template: @template)

      thing_entry = @thing.journal_entries.first
      assert_equal "refreshed", thing_entry.event
      assert_equal "Refreshed from template “Lamp”", thing_entry.message
      assert_equal({ "model" => [ "L1", "L2" ] }, thing_entry.field_changes)

      template_entry = @template.journal_entries.first
      assert_equal "refreshed", template_entry.event
      assert_equal "Refreshed 1 of 1 thing", template_entry.message
      assert_equal [ { "id" => @thing.id, "name" => "Lamp" } ], template_entry.things
    end

    test "leaves up to date things alone" do
      result = Refresh.call(template: @template)

      assert_empty result.updated
      assert_equal 1, result.unchanged
      assert_equal 1, @thing.journal_entries.count
    end
  end
end
