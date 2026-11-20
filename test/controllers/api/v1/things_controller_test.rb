require "test_helper"

class Api::V1::ThingsControllerTest < ActionDispatch::IntegrationTest
  TOKEN = "links_ingester_token".freeze

  def bearer(token = TOKEN)
    { "Authorization" => "Bearer #{token}" }
  end

  def json
    JSON.parse(response.body)
  end

  test "rejects a request without a key" do
    get api_v1_things_path

    assert_response :unauthorized
    assert_equal 'Bearer realm="api"', response.headers["WWW-Authenticate"]
    assert_equal "A valid API key is required", json["error"]
  end

  test "rejects a wrong key" do
    get api_v1_things_path, headers: bearer("links_wrong_token")
    assert_response :unauthorized
  end

  test "rejects a deleted key" do
    api_keys(:ingester).destroy!

    get api_v1_things_path, headers: bearer
    assert_response :unauthorized
  end

  test "rejects the key in a query parameter or as basic auth" do
    get api_v1_things_path, params: { api_key: TOKEN, token: TOKEN }
    assert_response :unauthorized

    get api_v1_things_path, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(TOKEN, "") }
    assert_response :unauthorized
  end

  test "a signed-in session is not enough" do
    sign_in_as(users(:local_admin))

    get api_v1_things_path
    assert_response :unauthorized
  end

  test "the network whitelist is not enough" do
    with_network_whitelist("10.0.0.0/8") do
      get api_v1_things_path, headers: from_network("10.1.2.3")
      assert_response :unauthorized
    end
  end

  test "records when the key was used" do
    get api_v1_things_path, headers: bearer

    assert_response :success
    assert_not_nil api_keys(:ingester).reload.last_used_at
  end

  test "lists every thing with pagination" do
    get api_v1_things_path, headers: bearer

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal Thing.order(:id).pluck(:id), json["things"].map { |thing| thing["id"] }
    assert_equal({ "page" => 1, "per_page" => 100, "count" => Thing.count, "pages" => 1, "next" => nil }, json["pagination"])
  end

  test "pages through things" do
    get api_v1_things_path, params: { per_page: 1 }, headers: bearer

    assert_equal [ Thing.order(:id).first.id ], json["things"].map { |thing| thing["id"] }
    assert_equal 2, json["pagination"]["next"]
    assert_equal Thing.count, json["pagination"]["pages"]

    get api_v1_things_path, params: { per_page: 1, page: 2 }, headers: bearer
    assert_equal [ Thing.order(:id).second.id ], json["things"].map { |thing| thing["id"] }
  end

  test "a page past the end is empty" do
    get api_v1_things_path, params: { page: 99 }, headers: bearer

    assert_response :success
    assert_equal [], json["things"]
    assert_nil json["pagination"]["next"]
  end

  test "caps per_page" do
    get api_v1_things_path, params: { per_page: 10_000 }, headers: bearer

    assert_equal 500, json["pagination"]["per_page"]
  end

  test "filters by updated_since" do
    Thing.update_all(updated_at: 2.days.ago)
    things(:router).touch

    get api_v1_things_path, params: { updated_since: 1.day.ago.iso8601 }, headers: bearer

    assert_response :success
    assert_equal [ things(:router).id ], json["things"].map { |thing| thing["id"] }
  end

  test "updated_since catches a thing whose only change was a link" do
    Thing.update_all(updated_at: 2.days.ago)
    thing_links(:keyboard_slack).update!(note: "Moved channels")

    get api_v1_things_path, params: { updated_since: 1.day.ago.iso8601 }, headers: bearer

    assert_equal [ things(:keyboard).id ], json["things"].map { |thing| thing["id"] }
  end

  test "rejects a malformed updated_since" do
    get api_v1_things_path, params: { updated_since: "last tuesday" }, headers: bearer

    assert_response :bad_request
    assert_equal "updated_since must be an ISO 8601 time", json["error"]
  end

  test "shows a thing by id, key, slug, and retired alias" do
    thing = things(:keyboard)

    [ thing.id.to_s, thing.key, thing.slug, "oldkbd12", "old-keyboard" ].each do |param|
      get api_v1_thing_path(param), headers: bearer

      assert_response :success, "looking up #{param}"
      assert_equal thing.id, json["thing"]["id"]
    end
  end

  test "answers 404 in JSON for an unknown thing" do
    get api_v1_thing_path("nope-not-here"), headers: bearer

    assert_response :not_found
    assert_equal({ "error" => "Not found" }, json)
  end

  test "describes a thing fully" do
    router = things(:router)
    attach_photo(router)
    attach_ar_anchor(router)

    get api_v1_thing_path(router.key), headers: bearer
    thing = json["thing"]

    assert_equal "Router", thing["name"]
    assert_equal "Main network router", thing["description"]
    assert_equal "Rack 2, front of shelf", thing["notes"]
    assert_equal "romkey", thing["owner"]
    assert_equal "192.168.1.1", thing["ip_address"]
    assert_equal "94:2a:6f:26:c6:ca", thing["ieee_address"]
    assert_equal "rtr12345", thing["key"]
    assert_equal "http://www.example.com/things/#{router.to_param}", thing["url"]
    assert_equal ShortUrl.display_url(router), thing["short_url"]
    assert thing.key?("updated_at")

    assert_equal [ "Where", "Wiki", "Manual" ], thing["links"].map { |link| link["title"] }
    wiki = thing["links"].find { |link| link["type"] == "wiki" }
    assert_equal "wiki", wiki["type"]
    assert_equal "https://wiki.example.com/router", wiki["url"]
    assert_equal "Front rack label", wiki["note"]
    assert_equal "custom", thing["links"].last["type"]

    assert_equal [ { "id" => things(:keyboard).id, "key" => "kbd12345", "slug" => "front-door-keyboard",
                     "name" => "Keyboard", "url" => "http://www.example.com/things/front-door-keyboard",
                     "note" => "Front door pair" } ], thing["related_things"]

    assert_equal [ "ar_anchor.png" ], thing["photos"].map { |photo| photo["filename"] }
    assert_equal "image/png", thing["photos"].first["content_type"]
    assert_match %r{\Ahttp://www.example.com/rails/active_storage/blobs/}, thing["photos"].first["url"]
    assert_equal "ar_anchor.png", thing["ar_anchor"]["filename"]

    integrations = thing["integrations"]
    assert_equal [ "USW-24-PoE" ], integrations["unifi_devices"].map { |device| device["model"] }
    assert_equal router.unifi_hosts.count, integrations["unifi_hosts"].size
    assert_equal router.prusa_connect_printers.count, integrations["prusa_connect_printers"].size
    assert_equal [], integrations["zigbee2mqtt_devices"]
  end

  test "includes aliases and template" do
    keyboard = things(:keyboard)
    template = ThingTemplate.first
    keyboard.update_columns(thing_template_id: template.id)

    get api_v1_thing_path(keyboard.key), headers: bearer

    assert_equal [ { "key" => "oldkbd12", "slug" => "old-keyboard" } ], json["thing"]["aliases"]
    assert_equal({ "id" => template.id, "name" => template.name }, json["thing"]["template"])
    assert_nil json["thing"]["ar_anchor"]
  end

  test "leaves out raw integration payloads and applied attributes" do
    unifi_devices(:rack_switch).update_columns(payload: { "secret_marker" => "do-not-leak" })

    get api_v1_things_path, headers: bearer

    assert_not_includes response.body, "do-not-leak"
    assert_not_includes response.body, "applied_attributes"
    assert_not_includes response.body, "payload"
  end

  test "is read-only" do
    thing = things(:keyboard)

    assert_no_changes -> { [ Thing.count, thing.reload.updated_at ] } do
      post "/api/v1/things", params: { thing: { name: "New" } }, headers: bearer
      assert_response :not_found

      patch "/api/v1/things/#{thing.id}", params: { thing: { name: "Changed" } }, headers: bearer
      assert_response :not_found

      delete "/api/v1/things/#{thing.id}", headers: bearer
      assert_response :not_found
    end
  end
end
