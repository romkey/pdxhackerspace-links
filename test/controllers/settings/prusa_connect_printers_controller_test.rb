require "test_helper"

class Settings::PrusaConnectPrintersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
    @printer = prusa_connect_printers(:mk4)
  end

  test "unlinking a printer keeps the thing" do
    thing = @printer.thing

    post unlink_settings_prusa_connect_printer_path(@printer), headers: { "HTTP_REFERER" => thing_url(thing) }

    @printer.reload
    assert_nil @printer.thing
    assert_not @printer.auto_link?
    assert_not @printer.ignored?
    assert Thing.exists?(thing.id)
    assert_equal :unlinked, PrusaConnect::SyncThing.call(prusa_connect_printer: @printer)
    assert_redirected_to thing_path(thing)
  end

  test "linking an unlinked printer attaches it again" do
    thing = @printer.thing
    Integrations::Unlink.call(@printer)

    post link_settings_prusa_connect_printer_path(@printer)

    assert_equal thing, @printer.reload.thing
    assert @printer.auto_link?
  end
end
