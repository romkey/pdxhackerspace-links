# Feeds Metrics::Recorder from Rails' own instrumentation. Recording is a no-op
# unless METRICS_TOKEN is set. See "Metrics" in the README.
Rails.application.config.after_initialize { Metrics.booted_at }

ActiveSupport::Notifications.subscribe(/\Aenqueue(_at)?\.active_job\z/) do |event|
  next if event.payload[:exception_object]

  Metrics::Recorder.job_enqueued(event.payload[:job])
end

ActiveSupport::Notifications.subscribe("perform.active_job") do |event|
  Metrics::Recorder.job_performed(
    event.payload[:job],
    duration: event.duration / 1000.0,
    error: event.payload[:exception_object]
  )
end

ActiveSupport::Notifications.subscribe("process_action.action_controller") do |event|
  payload = event.payload
  Metrics::Recorder.request(
    controller: payload[:controller],
    action: payload[:action],
    method: payload[:method],
    status: payload[:status] || 500,
    duration: event.duration / 1000.0
  )
end
