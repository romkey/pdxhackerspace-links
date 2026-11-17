require "test_helper"

class MetricsControllerTest < ActionDispatch::IntegrationTest
  TOKEN = "scrape-secret".freeze

  def bearer(token = TOKEN)
    { "Authorization" => "Bearer #{token}" }
  end

  test "is not found when no token is configured" do
    with_metrics_token(nil) do
      get metrics_path, headers: bearer

      assert_response :not_found
      assert_empty response.body
    end
  end

  test "is not found for a blank token, even when the request sends a blank one" do
    with_metrics_token("") do
      get metrics_path, headers: { "Authorization" => "Bearer " }

      assert_response :not_found
    end
  end

  test "rejects a request without a token" do
    with_metrics_token(TOKEN) do
      get metrics_path

      assert_response :unauthorized
      assert_equal 'Bearer realm="metrics"', response.headers["WWW-Authenticate"]
      assert_empty response.body
    end
  end

  test "rejects the wrong token" do
    with_metrics_token(TOKEN) do
      get metrics_path, headers: bearer("scrape-secre")
      assert_response :unauthorized

      get metrics_path, headers: bearer("#{TOKEN}x")
      assert_response :unauthorized
    end
  end

  test "does not accept the token as a query parameter or basic auth" do
    with_metrics_token(TOKEN) do
      get metrics_path(token: TOKEN)
      assert_response :unauthorized

      get metrics_path, headers: {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("prometheus", TOKEN)
      }
      assert_response :unauthorized
    end
  end

  test "a signed-in session is not enough" do
    with_metrics_token(TOKEN) do
      sign_in_as(users(:local_admin))
      get metrics_path

      assert_response :unauthorized
    end
  end

  test "the network whitelist is not enough" do
    with_metrics_token(TOKEN) do
      with_network_whitelist("192.168.0.0/16") do
        get metrics_path, env: from_network("192.168.1.20")

        assert_response :unauthorized
      end
    end
  end

  test "serves the Prometheus text format to the right token" do
    with_metrics_token(TOKEN) do
      get metrics_path, headers: bearer

      assert_response :success
      assert_equal "text/plain; version=0.0.4; charset=utf-8", response.headers["Content-Type"]
      assert_match(/^# TYPE links_app_info gauge$/, response.body)
      assert_match(/^links_app_info\{version="#{Regexp.escape(Links::Version.current)}",/, response.body)
      assert_match(/^links_users\{provider="local"\} \d+$/, response.body)
      assert_match(/^links_scrape_collector_success\{collector="records"\} 1$/, response.body)
    end
  end

  test "accepts a lowercase bearer scheme" do
    with_metrics_token(TOKEN) do
      get metrics_path, headers: { "Authorization" => "bearer #{TOKEN}" }

      assert_response :success
    end
  end

  test "counts requests, including sign-ins" do
    with_metrics_token(TOKEN) do
      sign_in_as(users(:local_admin))
      with_local_auth(email: users(:local_admin).email) do
        post local_login_path, params: { email: users(:local_admin).email, password: "wrong" }
      end
      get metrics_path, headers: bearer

      body = response.body
      assert_includes body, 'links_logins_total{provider="local",result="success"} 1'
      assert_includes body, 'links_logins_total{provider="local",result="failure"} 1'
      assert_includes body,
                      'links_http_requests_total{action="create",controller="LocalSessionsController",method="POST",status="302"} 1'
      assert_includes body,
                      'links_http_request_duration_seconds_count{action="create",controller="LocalSessionsController"} 2'
    end
  end

  test "records nothing while metrics are off" do
    with_metrics_token(nil) do
      get login_path

      assert_empty Metrics.store.read("http_requests_total")
    end
  end
end
