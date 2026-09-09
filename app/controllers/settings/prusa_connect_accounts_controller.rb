module Settings
  class PrusaConnectAccountsController < BaseController
    before_action :set_prusa_connect_account, only: %i[show edit update destroy test_connection import]

    def index
      @prusa_connect_accounts = PrusaConnectAccount.ordered
    end

    def show
      @prusa_connect_printers = @prusa_connect_account.prusa_connect_printers.includes(:thing).ordered
      @prusa_connect_printers = @prusa_connect_printers.active unless show_archived?
    end

    def new
      @prusa_connect_account = PrusaConnectAccount.new(enabled: true, auto_create_things: true)
    end

    def edit
    end

    def create
      @prusa_connect_account = PrusaConnectAccount.new(prusa_connect_account_params)

      if @prusa_connect_account.save
        redirect_to settings_prusa_connect_account_path(@prusa_connect_account),
                    notice: "Prusa Connect account was added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @prusa_connect_account.update(prusa_connect_account_params)
        redirect_to settings_prusa_connect_account_path(@prusa_connect_account),
                    notice: "Prusa Connect account was updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @prusa_connect_account.destroy!
      redirect_to settings_prusa_connect_accounts_path, notice: "Prusa Connect account was deleted."
    end

    def test_connection
      result = PrusaConnect::TestConnection.call(prusa_connect_account: @prusa_connect_account)

      redirect_to settings_prusa_connect_account_path(@prusa_connect_account),
                  (result.success? ? :notice : :alert) => result.message
    end

    def import
      unless @prusa_connect_account.enabled?
        return redirect_to settings_prusa_connect_account_path(@prusa_connect_account),
                           alert: "Enable #{@prusa_connect_account.name} before running an import."
      end

      @prusa_connect_account.update!(last_sync_status: "running", last_sync_message: "Import queued.")
      PrusaConnect::ImportJob.perform_later(@prusa_connect_account.id)

      redirect_to settings_prusa_connect_account_path(@prusa_connect_account),
                  notice: "Import started for #{@prusa_connect_account.name}. Reload to see the results."
    end

    private

    def set_prusa_connect_account
      @prusa_connect_account = PrusaConnectAccount.find(params[:id])
    end

    def show_archived?
      params[:archived] == "1"
    end
    helper_method :show_archived?

    def prusa_connect_account_params
      permitted = params.require(:prusa_connect_account).permit(
        :name,
        :refresh_token,
        :auto_create_things,
        :description,
        :enabled
      )

      if @prusa_connect_account&.persisted? && permitted[:refresh_token].blank?
        permitted.delete(:refresh_token)
      end
      permitted
    end
  end
end
