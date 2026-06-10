module Settings
  class SiteController < BaseController
    before_action :set_site_setting

    def show
      @cups_client = Cups::Client.new(server: @site_setting.cups_server)
      @cups_reachable = @cups_client.reachable?
      @cups_queues = @cups_reachable ? @cups_client.queue_names : []
    end

    def update
      if @site_setting.update(site_setting_params)
        redirect_to settings_site_path, notice: "Site settings were updated."
      else
        @cups_client = Cups::Client.new(server: @site_setting.cups_server)
        @cups_reachable = @cups_client.reachable?
        @cups_queues = @cups_reachable ? @cups_client.queue_names : []
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_site_setting
      @site_setting = SiteSetting.instance
    end

    def site_setting_params
      params.require(:site_setting).permit(:cups_server)
    end
  end
end
