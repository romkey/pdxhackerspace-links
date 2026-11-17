require "test_helper"

class Metrics::ReportTest < ActiveSupport::TestCase
  def render(*names)
    Metrics::Report.render(collectors: Metrics::Report::COLLECTORS.slice(*names))
  end

  def assert_sample(body, name, labels, value)
    line = body.lines.map(&:chomp).find do |candidate|
      candidate.start_with?("#{name}{") && labels.all? { |key, label| candidate.include?(%(#{key}="#{label}")) }
    end
    assert line, "No #{name} sample with #{labels.inspect} in:\n#{body}"
    assert_equal value.to_s, line.split.last, line
  end

  test "reports users by provider" do
    User.create!(email: "sso@example.com", name: "SSO", provider: "openid_connect", uid: "abc")
    body = render("records")

    assert_sample body, "links_users", { provider: "local" }, User.where(provider: nil).count
    assert_sample body, "links_users", { provider: "openid_connect" }, User.where(provider: "openid_connect").count
  end

  test "reports things, scans, and printers" do
    Thing.update_all(qr_scan_count: 0, nfc_scan_count: 0, visit_count: 0)
    things(:router).update_columns(qr_scan_count: 4, nfc_scan_count: 2, visit_count: 9, public_access: true)
    body = render("records")

    total = body.lines.grep(/^links_things\{/).sum { |line| line.split.last.to_i }
    assert_equal Thing.count, total
    assert_match(/^links_things_public #{Thing.where(public_access: true).count}$/, body)
    assert_sample body, "links_thing_scans", { type: "qr" }, 4
    assert_sample body, "links_thing_scans", { type: "nfc" }, 2
    assert_match(/^links_thing_visits 9$/, body)
    assert_match(/^links_thing_templates #{ThingTemplate.count}$/, body)
    assert_match(/^links_printers\{type="[a-z_]+",enabled="(true|false)"\} \d+$/, body)
  end

  test "reports each integration source and its last import" do
    controller = unifi_controllers(:udm)
    controller.update_columns(last_sync_status: "failed", last_synced_at: Time.zone.at(1_700_000_000))
    body = render("integrations")
    labels = { integration: "unifi", source: controller.name }

    assert_sample body, "links_integration_source_enabled", labels, 1
    assert_sample body, "links_integration_source_enabled",
                  { integration: "unifi", source: unifi_controllers(:retired).name }, 0
    assert_sample body, "links_integration_source_last_sync_timestamp_seconds", labels, 1_700_000_000
    assert_sample body, "links_integration_source_last_sync_status", labels.merge(status: "failed"), 1
    assert_sample body, "links_integration_source_last_sync_status", labels.merge(status: "success"), 0
    assert_match(/^links_integration_source_enabled\{integration="zigbee2mqtt",/, body)
    assert_match(/^links_integration_source_enabled\{integration="prusa_connect",/, body)
  end

  test "counts imported devices by state" do
    controller = unifi_controllers(:udm)
    devices = controller.unifi_devices
    expected = {
      "archived" => devices.where.not(archived_at: nil).count,
      "ignored" => devices.where(archived_at: nil, ignored: true).count,
      "linked" => devices.where(archived_at: nil, ignored: false).where.not(thing_id: nil).count,
      "unlinked" => devices.where(archived_at: nil, ignored: false, thing_id: nil).count
    }
    assert_operator devices.count, :>, 0, "fixture controller needs devices"
    body = render("integrations")

    expected.each do |state, count|
      assert_sample body, "links_integration_devices", { integration: "unifi", source: controller.name, state: state }, count
    end
  end

  test "reports job counters written by the recorder" do
    with_metrics_token do
      job = Unifi::ImportJob.new(1)
      Metrics::Recorder.job_performed(job, duration: 0.3)
      Metrics::Recorder.job_performed(job, duration: 45, error: RuntimeError.new("boom"))
      body = render("recorded")
      labels = { job: "Unifi::ImportJob", queue: "default" }

      assert_sample body, "links_job_executions_total", labels.merge(status: "success"), 1
      assert_sample body, "links_job_executions_total", labels.merge(status: "failed"), 1
      assert_sample body, "links_job_failures_total", labels.merge(error: "RuntimeError"), 1
      assert_sample body, "links_job_duration_seconds_bucket", labels.merge(le: "0.1"), 0
      assert_sample body, "links_job_duration_seconds_bucket", labels.merge(le: "0.5"), 1
      assert_sample body, "links_job_duration_seconds_bucket", labels.merge(le: "60"), 2
      assert_sample body, "links_job_duration_seconds_bucket", labels.merge(le: "+Inf"), 2
      assert_sample body, "links_job_duration_seconds_sum", labels, 45.3
      assert_sample body, "links_job_duration_seconds_count", labels, 2
      assert_includes body, "# TYPE links_job_duration_seconds histogram"
    end
  end

  test "reports the web process and database pool" do
    body = render("app", "runtime")

    assert_match(/^links_web_process_start_time_seconds \d/, body)
    assert_match(/^links_db_pool_size \d+$/, body)
    assert_match(/^links_db_pool_connections\{state="busy"\} \d+$/, body)
    assert_match(/^links_database_size_bytes \d+$/, body)
    assert_match(/^links_web_threads \d+$/, body)
  end

  test "a failing collector is reported without failing the scrape" do
    failing = Module.new { def self.call(_out) = raise("redis is down") }
    body = Metrics::Report.render(collectors: { "broken" => failing, "app" => "Metrics::Collectors::App" })

    assert_includes body, 'links_scrape_collector_success{collector="broken"} 0'
    assert_includes body, 'links_scrape_collector_success{collector="app"} 1'
    assert_match(/^links_scrape_collector_duration_seconds\{collector="broken"\} /, body)
    assert_includes body, "links_app_info{"
  end

  test "every line is a comment or a well-formed sample" do
    with_metrics_token do
      Metrics::Recorder.request(controller: "ThingsController", action: "index", method: "get", status: 200, duration: 0.02)
      body = Metrics::Report.render

      body.each_line(chomp: true) do |line|
        assert_match(/\A(# (HELP|TYPE) links_\w+ .+|links_\w+(\{(\w+="(\\.|[^"\\])*",?)+\})? -?[\d.e+-]+)\z/, line)
      end
      types = body.lines.grep(/^# TYPE/)
      assert_equal types.uniq, types, "a metric family was declared twice"
    end
  end
end
