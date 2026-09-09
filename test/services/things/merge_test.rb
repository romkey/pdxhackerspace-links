require "test_helper"

class Things::MergeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @target = things(:keyboard)
    @source = things(:router)
  end

  test "applies resolved attributes and deletes the source" do
    assert_difference -> { Thing.count }, -1 do
      merge(attributes: { "name" => "Front door keyboard", "owner" => "romkey" })
    end

    @target.reload
    assert_equal "Front door keyboard", @target.name
    assert_equal "romkey", @target.owner
    assert_not Thing.exists?(@source.id)
  end

  test "refuses to merge a thing into itself" do
    assert_raises ArgumentError do
      Things::Merge.call(target: @target, source: @target)
    end
  end

  test "transfers uniquely indexed values from the source" do
    merge(attributes: {
      "ieee_address" => @source.ieee_address,
      "ble_beacon_uuid" => @source.ble_beacon_uuid
    })

    @target.reload
    assert_equal "94:2a:6f:26:c6:ca", @target.ieee_address
    assert_equal "fda50693-f4c2-4a1b-8fb9-9d9458836f36", @target.ble_beacon_uuid
  end

  test "retires the source key as an alias" do
    retired = @source.key

    merge

    assert_equal @target, ThingAlias.find_by(key: retired).thing
    assert_equal @target, Thing.find_by_param!(retired)
  end

  test "retires the source slug as an alias" do
    @source.update!(slug: "main-router")

    merge

    assert_equal @target, Thing.find_by_param!("main-router")
  end

  test "does not retire a slug the target adopts" do
    @source.update!(slug: "main-router")

    merge(attributes: { "slug" => "main-router" })

    assert_equal "main-router", @target.reload.slug
    assert_nil ThingAlias.find_by(slug: "main-router")
  end

  test "carries the source's own aliases over to the target" do
    ThingAlias.create!(thing: @source, key: "oldrtr12")

    merge

    assert_equal @target, ThingAlias.find_by(key: "oldrtr12").thing
  end

  test "keeps imported devices linked to the target" do
    merge

    [ unifi_devices(:rack_switch), prusa_connect_printers(:mk4) ].each do |device|
      device.reload
      assert_equal @target.id, device.thing_id, "#{device.class.name} was not moved"
      assert_not device.ignored?, "#{device.class.name} was marked ignored"
    end
  end

  test "fills in the integration source when the target has none" do
    merge

    assert_equal "unifi", @target.reload.integration_source
  end

  test "keeps the target's integration source when it has one" do
    @target.update!(integration_source: "zigbee2mqtt")

    merge

    assert_equal "zigbee2mqtt", @target.reload.integration_source
  end

  test "adds the source's scan and visit counts" do
    @target.update!(qr_scan_count: 2, nfc_scan_count: 0, visit_count: 5)
    @source.update!(qr_scan_count: 3, nfc_scan_count: 1, visit_count: 4)

    merge

    @target.reload
    assert_equal 5, @target.qr_scan_count
    assert_equal 1, @target.nfc_scan_count
    assert_equal 9, @target.visit_count
  end

  test "keeps the earlier labelled date" do
    @target.update!(labelled_at: 1.day.ago)
    @source.update!(labelled_at: 1.week.ago)

    merge

    assert_in_delta 1.week.ago, @target.reload.labelled_at, 5
  end

  test "moves custom links to the target" do
    merge

    titles = @target.reload.custom_links.map(&:title)
    assert_equal [ "Manual" ], titles
  end

  test "skips a custom link the target already has" do
    @target.links.create!(link_type: :custom, title: "Manual", url: thing_links(:router_custom).url, position: 0)

    merge

    assert_equal 1, @target.reload.custom_links.size
  end

  test "positions moved custom links after the target's own" do
    @target.links.create!(link_type: :custom, title: "Datasheet", url: "https://example.com/datasheet", position: 0)

    merge

    assert_equal [ "Datasheet", "Manual" ], @target.reload.custom_links.map(&:title)
  end

  test "writes resolved standard links" do
    merge(links: { "asset" => { "url" => thing_links(:router_asset).url, "note" => "Front rack label" } })

    link = @target.reload.links.find_by(link_type: :asset)
    assert_equal thing_links(:router_asset).url, link.url
    assert_equal "Front rack label", link.note
  end

  test "removes a standard link resolved to blank" do
    merge(links: { "wiki" => { "url" => "", "note" => "" } })

    assert_nil @target.reload.links.find_by(link_type: :wiki)
  end

  test "drops the relationship between the two things being merged" do
    assert_difference -> { ThingRelationship.count }, -2 do
      merge
    end

    assert_empty @target.reload.related_things
  end

  test "moves the source's other relationships to the target" do
    dongle = Thing.create!(name: "Dongle")
    @source.thing_relationships.create!(related_thing: dongle, note: "Ships together")

    merge

    assert_equal [ dongle ], @target.reload.related_things.to_a
    assert_equal "Ships together", @target.thing_relationships.first.note
    assert_equal [ @target ], dongle.reload.related_things.to_a
  end

  test "skips a relationship the target already has" do
    dongle = Thing.create!(name: "Dongle")
    @target.thing_relationships.create!(related_thing: dongle, note: "Keep this note")
    @source.thing_relationships.create!(related_thing: dongle, note: "Drop this note")

    merge

    assert_equal [ dongle ], @target.reload.related_things.to_a
    assert_equal "Keep this note", @target.thing_relationships.first.note
  end

  test "moves photos to the target without purging their blobs" do
    attach_photo(@source)

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      merge
    end

    assert_equal 1, @target.reload.photos.count
  end

  test "keeps photos the target already has" do
    attach_photo(@target)
    attach_photo(@source)

    merge

    assert_equal 2, @target.reload.photos.count
  end

  test "moves the ar marker when the target has none" do
    attach_ar_anchor(@source)

    merge

    assert @target.reload.ar_anchor.attached?
  end

  test "keeps the target's own ar marker" do
    attach_ar_anchor(@target)
    attach_ar_anchor(@source)
    target_blob_id = @target.ar_anchor.blob_id

    merge

    assert_equal target_blob_id, @target.reload.ar_anchor.blob_id
  end

  test "rolls back everything when the resolved attributes are invalid" do
    assert_no_difference [ -> { Thing.count }, -> { ThingAlias.count } ] do
      assert_raises ActiveRecord::RecordInvalid do
        merge(attributes: { "name" => "" })
      end
    end

    assert_equal @source.id, unifi_devices(:rack_switch).reload.thing_id
  end

  private

  def merge(attributes: {}, links: {})
    Things::Merge.call(target: @target, source: @source, attributes: attributes, links: links)
  end
end
