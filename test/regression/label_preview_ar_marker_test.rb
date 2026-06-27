require "test_helper"

class LabelPreviewArMarkerRegressionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "label preview pdf succeeds with ar marker attached" do
    attach_ar_anchor(things(:router))

    get label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  test "label preview pdf succeeds when ar marker file is missing from storage" do
    attach_ar_anchor(things(:router))
    blob = things(:router).ar_anchor.blob
    ActiveStorage::Blob.service.delete(blob.key)

    get label_preview_thing_path(things(:router), printer_id: printers(:label_printer).id, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end
end
