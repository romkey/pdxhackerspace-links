require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  test "generate makes a random token and stores only its digest and prefix" do
    key = ApiKey.generate(name: "Ingester", user: users(:local_admin))
    key.save!

    assert_match(/\Alinks_[1-9A-HJ-NP-Za-km-z]{40}\z/, key.token)
    assert_equal ApiKey.digest(key.token), key.token_digest
    assert_equal key.token.first(ApiKey::PREFIX_LENGTH), key.token_prefix
    assert_not_includes ApiKey.find(key.id).attributes.values, key.token
    assert_nil ApiKey.find(key.id).token
  end

  test "generated tokens differ" do
    assert_not_equal ApiKey.generate(name: "a").token, ApiKey.generate(name: "b").token
  end

  test "authenticate finds the key for its token" do
    assert_equal api_keys(:ingester), ApiKey.authenticate("links_ingester_token")
  end

  test "authenticate rejects unknown, blank, and nil tokens" do
    assert_nil ApiKey.authenticate("links_wrong_token")
    assert_nil ApiKey.authenticate("")
    assert_nil ApiKey.authenticate(nil)
  end

  test "authenticate rejects the stored digest itself" do
    assert_nil ApiKey.authenticate(api_keys(:ingester).token_digest)
  end

  test "authenticate records when the key was last used, at most once a minute" do
    key = api_keys(:ingester)
    assert_nil key.last_used_at

    freeze_time do
      ApiKey.authenticate("links_ingester_token")
      assert_equal Time.current, key.reload.last_used_at
    end

    first_use = key.last_used_at
    travel 30.seconds do
      ApiKey.authenticate("links_ingester_token")
      assert_equal first_use, key.reload.last_used_at
    end

    travel 2.minutes do
      ApiKey.authenticate("links_ingester_token")
      assert_operator key.reload.last_used_at, :>, first_use
    end
  end

  test "requires a unique name" do
    key = ApiKey.generate(name: " rag INGESTER ")
    assert_not key.valid?
    assert_includes key.errors[:name], "has already been taken"

    assert_not ApiKey.generate(name: "  ").valid?
  end

  test "has no expiry" do
    key = api_keys(:ingester)
    key.update_columns(created_at: 10.years.ago)

    assert_equal key, ApiKey.authenticate("links_ingester_token")
  end

  test "survives deletion of the user who created it" do
    key = api_keys(:ingester)
    key.user.destroy!

    assert_nil key.reload.user
    assert_equal key, ApiKey.authenticate("links_ingester_token")
  end
end
