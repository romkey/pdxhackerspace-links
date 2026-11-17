# Prometheus scrape endpoint. Deliberately outside ApplicationController: it is
# authenticated by METRICS_TOKEN alone, never by a session or the network
# whitelist, and answers 404 until a token is configured.
class MetricsController < ActionController::API
  def show
    return head :not_found unless Metrics.enabled?

    unless authorized?
      response.headers["WWW-Authenticate"] = 'Bearer realm="metrics"'
      return head :unauthorized
    end

    render plain: Metrics::Report.render, content_type: Metrics::Exposition::CONTENT_TYPE
  end

  private

  def authorized?
    provided = request.authorization.to_s[/\ABearer\s+(\S+)\z/i, 1]
    provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, Metrics.token)
  end
end
