require "test_helper"

class ThingTemplateApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "new lists templates" do
    get new_thing_template_application_path(things(:router))

    assert_response :success
    assert_select "a", text: "Raspberry Pi 4"
    assert_select "a", text: "Door sensor"
  end

  test "new with a template previews what will be filled without saving" do
    router = things(:router)

    get new_thing_template_application_path(router, template: thing_templates(:pi).id)

    assert_response :success
    assert_select "li", text: "Manufacturer"
    assert_select "li", text: "Datasheet"
    assert_select "li", text: "Owner", count: 0
    assert_nil router.reload.manufacturer
  end

  test "create applies the template" do
    router = things(:router)

    assert_difference -> { router.links.count }, 1 do
      post thing_template_application_path(router), params: { template: thing_templates(:pi).id }
    end

    router.reload
    assert_equal "Raspberry Pi Ltd", router.manufacturer
    assert_equal "Main network router", router.description
    assert_redirected_to thing_path(router)
    assert_match "Applied “Raspberry Pi 4”", flash[:notice]
    entry = router.journal_entries.sole
    assert_equal "Applied template “Raspberry Pi 4”", entry.message
    assert_equal [ nil, "Raspberry Pi Ltd" ], entry.field_changes["manufacturer"]
  end

  test "create without a template redirects back to the picker" do
    post thing_template_application_path(things(:router))

    assert_redirected_to new_thing_template_application_path(things(:router))
  end

  test "requires sign in" do
    delete logout_path
    get new_thing_template_application_path(things(:router))

    assert_redirected_to login_path
  end
end
