require "test_helper"

class ThingFormArMarkerRegressionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "edit form uses multipart encoding and has no nested forms" do
    attach_ar_anchor(things(:router))

    get edit_thing_path(things(:router))

    assert_response :success
    assert_select "form[action=?][enctype=?]", thing_path(things(:router)), "multipart/form-data", count: 1
    assert_select "form form", count: 0
  end

  test "edit form submits ar marker replacement" do
    attach_ar_anchor(things(:router))

    patch thing_path(things(:router)), params: {
      thing: {
        name: things(:router).name,
        ar_anchor: fixture_file_upload("ar_anchor.png", "image/png"),
        ar_anchor_note: "Replaced marker"
      }
    }

    assert_redirected_to thing_path(things(:router))
    router = things(:router).reload
    assert router.ar_anchor.attached?
    assert_equal "Replaced marker", router.ar_anchor_note
  end
end
