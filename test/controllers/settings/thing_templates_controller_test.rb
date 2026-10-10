require "test_helper"

class Settings::ThingTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
  end

  test "index lists templates" do
    get settings_thing_templates_path

    assert_response :success
    assert_select "td", text: "Raspberry Pi 4"
    assert_select "td", text: "Door sensor"
  end

  test "edit shows template fields and links" do
    get edit_settings_thing_template_path(thing_templates(:pi))

    assert_response :success
    assert_select "input[name='thing_template[model]'][value=?]", "Pi 4 Model B"
    assert_select "dt", text: "Datasheet"
  end

  test "update changes the template" do
    patch settings_thing_template_path(thing_templates(:pi)),
          params: { thing_template: { name: "Pi 4", model: "Pi 4 8GB" } }

    assert_redirected_to settings_thing_templates_path
    assert_equal "Pi 4", thing_templates(:pi).reload.name
    assert_equal "Pi 4 8GB", thing_templates(:pi).model
  end

  test "update with a duplicate name re-renders" do
    patch settings_thing_template_path(thing_templates(:pi)),
          params: { thing_template: { name: "door sensor" } }

    assert_response :unprocessable_entity
  end

  test "destroy deletes the template" do
    assert_difference -> { ThingTemplate.count }, -1 do
      delete settings_thing_template_path(thing_templates(:pi))
    end

    assert_redirected_to settings_thing_templates_path
  end

  test "edit lists things made from the template and its history" do
    template = thing_templates(:pi)
    thing = template.build_thing
    thing.save!
    template.update!(model: "Pi 5")

    get edit_settings_thing_template_path(template)

    assert_response :success
    assert_select "a[href=?]", thing_path(thing), text: "Raspberry Pi"
    assert_select "button", text: "Refresh things"
    assert_select ".journal li", text: /Model: Pi 4 Model B → Pi 5/
  end

  test "refresh updates things made from the template" do
    template = thing_templates(:pi)
    thing = template.build_thing
    thing.save!
    template.update!(owner: "team")

    post refresh_settings_thing_template_path(template)

    assert_redirected_to edit_settings_thing_template_path(template)
    assert_equal "Updated 1 of 1 thing from “Raspberry Pi 4”.", flash[:notice]
    assert_equal "team", thing.reload.owner
    assert_equal users(:local_admin), thing.journal_entries.first.user
  end
end
