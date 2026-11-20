require "test_helper"

class Settings::ApiKeysControllerTest < ActionDispatch::IntegrationTest
  test "requires a signed-in user" do
    get settings_api_keys_path
    assert_redirected_to login_path

    assert_no_difference -> { ApiKey.count } do
      post settings_api_keys_path, params: { api_key: { name: "Sneaky" } }
    end
    assert_redirected_to login_path
  end

  test "the network whitelist is not enough" do
    with_network_whitelist("10.0.0.0/8") do
      get settings_api_keys_path, headers: from_network("10.1.2.3")
      assert_redirected_to login_path
    end
  end

  test "lists keys by prefix only" do
    sign_in_as(users(:local_admin))

    get settings_api_keys_path

    assert_response :success
    assert_select "td", text: "RAG ingester"
    assert_select "code", text: "links_ingest…"
    assert_not_includes response.body, api_keys(:ingester).token_digest
    assert_select "a.settings-nav-item.active", text: "API keys"
  end

  test "creates a key and shows its token once" do
    sign_in_as(users(:local_admin))

    assert_difference -> { ApiKey.count }, 1 do
      post settings_api_keys_path, params: { api_key: { name: "New ingester" } }
    end

    assert_response :created
    assert_equal "no-store", response.headers["Cache-Control"]
    token = css_select("input[data-api-key-token]").first["value"]
    key = ApiKey.find_by!(name: "New ingester")
    assert_equal ApiKey.digest(token), key.token_digest
    assert_equal users(:local_admin), key.user
    assert_nil flash[:api_key_token]

    get settings_api_keys_path
    assert_not_includes response.body, token

    get api_v1_things_path, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
  end

  test "rejects a blank or duplicate name" do
    sign_in_as(users(:local_admin))

    assert_no_difference -> { ApiKey.count } do
      post settings_api_keys_path, params: { api_key: { name: "" } }
      assert_response :unprocessable_entity

      post settings_api_keys_path, params: { api_key: { name: "RAG ingester" } }
      assert_response :unprocessable_entity
    end
  end

  test "deleting a key revokes it" do
    sign_in_as(users(:local_admin))

    assert_difference -> { ApiKey.count }, -1 do
      delete settings_api_key_path(api_keys(:ingester))
    end
    assert_redirected_to settings_api_keys_path

    get api_v1_things_path, headers: { "Authorization" => "Bearer links_ingester_token" }
    assert_response :unauthorized
  end
end
