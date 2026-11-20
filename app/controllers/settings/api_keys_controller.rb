module Settings
  class ApiKeysController < BaseController
    def index
      @api_keys = ApiKey.includes(:user).ordered
    end

    def new
      @api_key = ApiKey.new
    end

    # Renders the token instead of redirecting: it is shown this once and
    # never stored, not even in the flash.
    def create
      @api_key = ApiKey.generate(name: api_key_params[:name], user: current_user)

      if @api_key.save
        response.headers["Cache-Control"] = "no-store"
        render :created, status: :created
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      api_key = ApiKey.find(params[:id])
      api_key.destroy!
      redirect_to settings_api_keys_path, notice: "API key “#{api_key.name}” was deleted. It no longer works."
    end

    private

    def api_key_params
      params.expect(api_key: [ :name ])
    end
  end
end
