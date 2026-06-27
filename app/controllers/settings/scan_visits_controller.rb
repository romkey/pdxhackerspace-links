module Settings
  class ScanVisitsController < BaseController
    def show
      @scan_stats = Things::ScanStats.call(
        sort: params[:sort],
        direction: params[:direction]
      )
    end
  end
end
