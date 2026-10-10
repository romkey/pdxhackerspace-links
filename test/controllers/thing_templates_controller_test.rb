require "test_helper"

class ThingTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "new shows template name defaulting to thing name and what will be saved" do
    get new_thing_template_path(things(:router))

    assert_response :success
    assert_select "input[name='thing_template[name]'][value=?]", "Router"
    assert_select "dd", text: "Main network router"
    assert_select "dd", text: "192.168.1.1", count: 0
  end

  test "create saves a template from the thing" do
    assert_difference -> { ThingTemplate.count }, 1 do
      post thing_templates_path(things(:router)), params: { thing_template: { name: "Core router" } }
    end

    template = ThingTemplate.find_by!(name: "Core router")
    assert_equal "Router", template.thing_name
    assert_redirected_to thing_path(things(:router))
    assert_equal "Saved template “Core router”.", flash[:notice]
  end

  test "create with an existing name replaces the template" do
    assert_no_difference -> { ThingTemplate.count } do
      post thing_templates_path(things(:router)), params: { thing_template: { name: "Raspberry Pi 4" } }
    end

    assert_equal "Router", thing_templates(:pi).reload.thing_name
    assert_equal "Replaced template “Raspberry Pi 4”.", flash[:notice]
  end

  test "create with a blank name re-renders" do
    assert_no_difference -> { ThingTemplate.count } do
      post thing_templates_path(things(:router)), params: { thing_template: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "requires sign in" do
    delete logout_path
    get new_thing_template_path(things(:router))

    assert_redirected_to login_path
  end
end
