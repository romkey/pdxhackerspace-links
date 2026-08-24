require "test_helper"

class ThingUpdatePhotosTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:local_admin))
    @thing = attach_photo(things(:router))
  end

  test "update without photos param preserves existing photos" do
    patch thing_path(@thing), params: {
      thing: {
        name: "Core Router",
        notes: "Moved to rack 3"
      }
    }

    assert_redirected_to thing_path(@thing)
    assert_equal 1, @thing.reload.photos.count
  end

  test "update with empty photos param preserves existing photos" do
    patch thing_path(@thing), params: {
      thing: {
        name: "Core Router",
        photos: []
      }
    }

    assert_redirected_to thing_path(@thing)
    assert_equal 1, @thing.reload.photos.count
  end

  test "update with new photo appends to existing photos" do
    patch thing_path(@thing), params: {
      thing: {
        name: @thing.name,
        photos: [ fixture_file_upload("ar_anchor.png", "image/png") ]
      }
    }

    assert_redirected_to thing_path(@thing)
    assert_equal 2, @thing.reload.photos.count
  end
end
