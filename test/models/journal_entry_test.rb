require "test_helper"

class JournalEntryTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "creating a thing records its fields and links" do
    thing = Thing.new(name: "Lamp", owner: "romkey")
    thing.link_for("wiki").url = "https://wiki.example.com/lamp"
    thing.links.build(link_type: :custom, title: "Manual", url: "https://example.com/lamp")
    thing.save!

    entry = thing.journal_entries.sole
    assert_equal "created", entry.event
    assert_equal [ nil, "Lamp" ], entry.field_changes["name"]
    assert_equal [ nil, "romkey" ], entry.field_changes["owner"]
    assert_not entry.field_changes.key?("public_access")
    assert_equal [ "Manual", "Wiki" ], entry.links_added.map { |link| link["label"] }.sort
  end

  test "updating a thing records changed fields and added, modified, and removed links" do
    thing = things(:router)

    thing.update!(
      owner: "someone",
      links_attributes: [
        { id: thing_links(:router_wiki).id, url: "https://wiki.example.com/router2", note: "Front rack label" },
        { id: thing_links(:router_custom).id, _destroy: "1" },
        { link_type: "slack", url: "https://slack.example.com/router" }
      ]
    )

    entry = thing.journal_entries.sole
    assert_equal "updated", entry.event
    assert_equal({ "owner" => [ "romkey", "someone" ] }, entry.field_changes)
    assert_equal [ "Slack" ], entry.links_added.map { |link| link["label"] }
    assert_equal [ "Manual" ], entry.links_removed.map { |link| link["label"] }
    assert_equal [ { "key" => "wiki", "label" => "Wiki",
                     "changes" => { "url" => [ "https://wiki.example.com/router", "https://wiki.example.com/router2" ] } } ],
                 entry.links_modified
  end

  test "clearing a standard link records it as removed" do
    thing = things(:router)

    thing.link_for("wiki").assign_attributes(url: "", note: "")
    thing.save!

    assert_equal [ "Wiki" ], thing.journal_entries.sole.links_removed.map { |link| link["label"] }
  end

  test "saving without changes records nothing" do
    thing = things(:router)

    assert_no_difference -> { JournalEntry.count } do
      thing.update!(owner: "romkey")
      thing.increment!(:visit_count)
      thing.mark_labelled!
    end
  end

  test "entries name the signed in user" do
    Current.user = users(:local_admin)

    things(:router).update!(owner: "someone")

    assert_equal users(:local_admin), things(:router).journal_entries.sole.user
  end

  test "things made from a template say so" do
    thing = thing_templates(:pi).build_thing
    thing.save!

    assert_equal thing_templates(:pi), thing.thing_template
    assert_equal "Created from template “Raspberry Pi 4”", thing.journal_entries.sole.message
  end

  test "template saves record field and link changes" do
    template = thing_templates(:pi)
    links = template.links.map(&:dup)
    links[0] = links[0].merge("note" => "New guide")
    links << { "link_type" => "slack", "url" => "https://slack.example.com/pi", "note" => nil }

    template.update!(model: "Pi 5", links: links)

    entry = template.journal_entries.sole
    assert_equal({ "model" => [ "Pi 4 Model B", "Pi 5" ] }, entry.field_changes)
    assert_equal [ "Slack" ], entry.links_added.map { |link| link["label"] }
    assert_equal({ "note" => [ "Setup guide", "New guide" ] }, entry.links_modified.sole["changes"])
  end

  test "duplicating records one entry with the copied links" do
    copy = Things::Duplicate.call(thing: things(:router))

    entry = copy.journal_entries.sole
    assert_equal "Duplicated from “Router”", entry.message
    assert_equal %w[Manual Where Wiki], entry.links_added.map { |link| link["label"] }.sort
  end

  test "merging records one entry on the kept thing" do
    target = things(:router)
    source = things(:keyboard)

    Things::Merge.call(target: target, source: source,
                       links: { "slack" => { "url" => "https://slack.example.com/archives/keyboard" } })

    entry = target.journal_entries.sole
    assert_equal "merged", entry.event
    assert_equal "Merged in “Keyboard”", entry.message
    assert_includes entry.links_added.map { |link| link["label"] }, "Slack"
  end
end
