require "test_helper"

class PrusaConnect::ImportJobTest < ActiveJob::TestCase
  test "imports the account" do
    account = prusa_connect_accounts(:main)
    called_with = nil

    stubbing(PrusaConnect::Import, :call, ->(**kwargs) { called_with = kwargs[:prusa_connect_account] }) do
      PrusaConnect::ImportJob.perform_now(account.id)
    end

    assert_equal account, called_with
  end

  test "does nothing for a disabled account" do
    account = prusa_connect_accounts(:disabled)

    stubbing(PrusaConnect::Import, :call, ->(**) { flunk "disabled accounts must be skipped" }) do
      PrusaConnect::ImportJob.perform_now(account.id)
    end

    assert_nil account.reload.last_synced_at
  end

  test "clears the queued marker when the account is disabled before the job runs" do
    account = prusa_connect_accounts(:disabled)
    account.update!(last_sync_status: "running", last_sync_message: "Import queued.")

    stubbing(PrusaConnect::Import, :call, ->(**) { flunk "disabled accounts must be skipped" }) do
      PrusaConnect::ImportJob.perform_now(account.id)
    end

    account.reload
    assert_not_predicate account, :syncing?
    assert_equal "skipped", account.last_sync_status
    assert_match "disabled", account.last_sync_message
  end

  test "records the failure on the account before re-raising" do
    account = prusa_connect_accounts(:main)

    stubbing(PrusaConnect::Import, :call, ->(**) { raise PrusaConnect::Client::ConnectionError, "Timed out" }) do
      assert_raises(PrusaConnect::Client::ConnectionError) { PrusaConnect::ImportJob.perform_now(account.id) }
    end

    account.reload
    assert_equal "failed", account.last_sync_status
    assert_equal "Timed out", account.last_sync_message
  end
end
