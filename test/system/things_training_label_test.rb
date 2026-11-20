require "application_system_test_case"

class ThingsTrainingLabelTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:local_admin))
  end

  test "checking training required adds it to the label name and unchecking leaves it" do
    router = things(:router)
    visit edit_thing_path(router, anchor: "links")

    check "Training required"
    step "Identity"
    assert_field "Label name", with: "Router - TRAINING REQUIRED"

    step "Links"
    uncheck "Training required"
    check "Training required"
    step "Identity"
    assert_field "Label name", with: "Router - TRAINING REQUIRED"

    step "Links"
    uncheck "Training required"
    step "Identity"
    assert_field "Label name", with: "Router - TRAINING REQUIRED"
  end

  test "the label name can be edited after training required adds to it" do
    router = things(:router)
    router.update!(label_name: "Rtr")
    visit edit_thing_path(router, anchor: "links")

    check "Training required"
    step "Identity"
    assert_field "Label name", with: "Rtr - TRAINING REQUIRED"

    fill_in "Label name", with: "Rtr"
    click_button "Save and Exit", match: :first

    assert_text "Router"
    router.reload
    assert router.training_required?
    assert_equal "Rtr", router.label_name
  end

  private

  def step(label)
    within("nav[aria-label='Thing form steps']") { click_link label }
  end
end
