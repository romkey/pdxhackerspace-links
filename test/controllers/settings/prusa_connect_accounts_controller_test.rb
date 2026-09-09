require "test_helper"

class Settings::PrusaConnectAccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "requires signing in" do
    delete logout_path

    get settings_prusa_connect_accounts_path
    assert_redirected_to login_path
  end

  test "index lists accounts" do
    get settings_prusa_connect_accounts_path

    assert_response :success
    assert_select "td", text: prusa_connect_accounts(:main).name
  end

  test "settings navigation links to Prusa Connect" do
    get settings_printers_path

    assert_select "a[href=?]", settings_prusa_connect_accounts_path, text: "Prusa Connect"
  end

  test "show lists imported printers and their things" do
    get settings_prusa_connect_account_path(prusa_connect_accounts(:main))

    assert_response :success
    assert_select "td", text: /Rack MK4/
    assert_select "a[href=?]", thing_path(things(:router))
  end

  test "show hides archived printers until asked" do
    get settings_prusa_connect_account_path(prusa_connect_accounts(:main))
    assert_select "td", { text: /Loft MINI/, count: 0 }

    get settings_prusa_connect_account_path(prusa_connect_accounts(:main), archived: "1")
    assert_select "td", text: /Loft MINI/
  end

  test "creates an account" do
    assert_difference -> { PrusaConnectAccount.count }, 1 do
      post settings_prusa_connect_accounts_path, params: {
        prusa_connect_account: {
          name: "Shop account",
          refresh_token: "a-new-refresh-token",
          auto_create_things: "1",
          enabled: "1"
        }
      }
    end

    account = PrusaConnectAccount.find_by(name: "Shop account")
    assert_redirected_to settings_prusa_connect_account_path(account)
    assert_equal "a-new-refresh-token", account.refresh_token
  end

  test "updating without a refresh token keeps the saved one" do
    account = prusa_connect_accounts(:main)

    patch settings_prusa_connect_account_path(account), params: {
      prusa_connect_account: { name: "Renamed account", refresh_token: "" }
    }

    account.reload
    assert_equal "Renamed account", account.name
    assert_equal "initial-refresh-token", account.refresh_token
  end

  test "updating with a refresh token replaces it" do
    account = prusa_connect_accounts(:main)

    patch settings_prusa_connect_account_path(account), params: {
      prusa_connect_account: { refresh_token: "rotated-refresh-token" }
    }

    assert_equal "rotated-refresh-token", account.reload.refresh_token
  end

  test "the form never renders the saved refresh token" do
    get edit_settings_prusa_connect_account_path(prusa_connect_accounts(:main))

    assert_response :success
    assert_select "input[name=?][value=?]", "prusa_connect_account[refresh_token]", "initial-refresh-token", count: 0
  end

  test "deletes an account" do
    assert_difference -> { PrusaConnectAccount.count }, -1 do
      delete settings_prusa_connect_account_path(prusa_connect_accounts(:disabled))
    end

    assert_redirected_to settings_prusa_connect_accounts_path
  end

  test "test connection reports success" do
    account = prusa_connect_accounts(:main)
    result = PrusaConnect::TestConnection::Result.new(printer_count: 2, errors: [])

    stubbing(PrusaConnect::TestConnection, :call, ->(**) { result }) do
      post test_connection_settings_prusa_connect_account_path(account)
    end

    assert_redirected_to settings_prusa_connect_account_path(account)
    assert_match "2 printers", flash[:notice]
  end

  test "test connection reports a failure as an alert" do
    account = prusa_connect_accounts(:main)
    result = PrusaConnect::TestConnection::Result.new(printer_count: nil, errors: [ "Token rejected" ])

    stubbing(PrusaConnect::TestConnection, :call, ->(**) { result }) do
      post test_connection_settings_prusa_connect_account_path(account)
    end

    assert_match "Token rejected", flash[:alert]
  end

  test "import queues a background job" do
    account = prusa_connect_accounts(:main)

    assert_enqueued_with(job: PrusaConnect::ImportJob, args: [ account.id ]) do
      post import_settings_prusa_connect_account_path(account)
    end

    assert_redirected_to settings_prusa_connect_account_path(account)
    assert_predicate account.reload, :syncing?
  end

  test "import refuses a disabled account instead of marking it running" do
    account = prusa_connect_accounts(:disabled)

    assert_no_enqueued_jobs(only: PrusaConnect::ImportJob) do
      post import_settings_prusa_connect_account_path(account)
    end

    assert_redirected_to settings_prusa_connect_account_path(account)
    assert_match "Enable", flash[:alert]
    assert_not_predicate account.reload, :syncing?
  end
end
