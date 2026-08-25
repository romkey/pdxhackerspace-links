require "test_helper"

class PublicThingAccessTest < ActionDispatch::IntegrationTest
  setup do
    delete logout_path
  end

  test "allows viewing public thing without authentication" do
    with_network_whitelist(nil) do
      get thing_path(things(:keyboard))
      assert_response :success
      assert_select "h1", /Keyboard/
      assert_select "a[href=?]", thing_links(:keyboard_wiki).url
      assert_select "a[href=?]", edit_thing_path(things(:keyboard)), count: 0
      assert_select "a[href=?]", login_path
    end
  end

  test "blocks viewing private thing without authentication" do
    with_network_whitelist(nil) do
      get thing_path(things(:router))
      assert_redirected_to login_path
      assert_equal "Please sign in to continue.", flash[:alert]
    end
  end

  test "public guest sees minimal navigation" do
    with_network_whitelist(nil) do
      get thing_path(things(:keyboard))
      assert_response :success
      assert_select "a[href=?]", root_path, count: 0
      assert_select "a[href=?]", things_path, count: 0
      assert_select "input[type=search]", count: 0
      assert_select "a[href=?]", login_path
    end
  end

  test "public guest cannot browse things index" do
    with_network_whitelist(nil) do
      get things_path
      assert_redirected_to login_path
    end
  end

  test "public guest cannot search things" do
    with_network_whitelist(nil) do
      get things_path, params: { q: "keyboard" }
      assert_redirected_to login_path
    end
  end

  test "public guest cannot edit public thing" do
    with_network_whitelist(nil) do
      get edit_thing_path(things(:keyboard))
      assert_redirected_to login_path
    end
  end

  test "public guest cannot print public thing" do
    with_network_whitelist(nil) do
      post print_thing_path(things(:keyboard)),
           params: { printer_id: printers(:brother_printer).id }

      assert_redirected_to login_path
    end
  end

  test "public guest visit counts increment on show" do
    with_network_whitelist(nil) do
      thing = things(:keyboard)
      assert_difference -> { thing.reload.visit_count }, 1 do
        get thing_path(thing)
      end
    end
  end

  test "signed in user can toggle public access" do
    sign_in_as(users(:local_admin))

    patch thing_path(things(:router)), params: { thing: { public_access: true } }
    assert_redirected_to thing_path(things(:router))
    assert things(:router).reload.public_access?

    delete logout_path

    with_network_whitelist(nil) do
      get thing_path(things(:router))
      assert_response :success
    end
  end

  test "network guest still sees full navigation on public thing" do
    with_network_whitelist("192.168.0.0/16") do
      get thing_path(things(:keyboard)), env: from_network("192.168.1.50")
      assert_response :success
      assert_select "a[href=?]", things_path
      assert_select "input[type=search]", count: 0
    end
  end
end
