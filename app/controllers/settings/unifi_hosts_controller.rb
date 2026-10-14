module Settings
  class UnifiHostsController < BaseController
    FILTERS = {
      "linked" => ->(scope) { scope.linked },
      "unlinked" => ->(scope) { scope.unlinked },
      "online" => ->(scope) { scope.online },
      "wireless" => ->(scope) { scope.wireless },
      "wired" => ->(scope) { scope.wired },
      "reserved" => ->(scope) { scope.reserved }
    }.freeze

    FILTER_LABELS = {
      "linked" => "Linked",
      "unlinked" => "Unlinked",
      "online" => "Online",
      "wireless" => "Wi-Fi",
      "wired" => "Wired",
      "reserved" => "Reserved IP"
    }.freeze

    def index
      @unifi_controller = UnifiController.find(params[:unifi_controller_id])
      @search_query = params[:q].to_s.strip.presence
      @filter = FILTERS.key?(params[:filter]) ? params[:filter] : nil

      scope = @unifi_controller.unifi_hosts.includes(:thing).search(@search_query)
      scope = show_archived? ? scope : scope.active
      scope = FILTERS[@filter].call(scope) if @filter
      @pagy, @unifi_hosts = pagy(:offset, scope.ordered, limit: Pagy::OPTIONS[:limit])
    end

    # Ignoring a host unlinks its thing and stops future imports from linking it.
    def update
      unifi_host = UnifiHost.find(params[:id])
      ignored = ActiveModel::Type::Boolean.new.cast(params[:ignored])

      if ignored
        unifi_host.update!(ignored: true, thing: nil)
        notice = "#{unifi_host.display_name} will no longer be linked to a thing."
      else
        unifi_host.update!(ignored: false)
        Unifi::LinkHost.call(unifi_host: unifi_host)
        notice = "#{unifi_host.display_name} will be linked again."
      end

      redirect_back_or_to settings_unifi_controller_unifi_hosts_path(unifi_host.unifi_controller), notice: notice
    end

    private

    def show_archived?
      params[:archived] == "1"
    end
    helper_method :show_archived?

    def hosts_index_params(overrides = {})
      {
        q: @search_query,
        filter: @filter,
        archived: (show_archived? ? "1" : nil)
      }.merge(overrides).compact_blank
    end
    helper_method :hosts_index_params
  end
end
