require "test_helper"

class Things::RecordVisitTest < ActiveSupport::TestCase
  test "increments visit count" do
    thing = things(:keyboard)
    thing.update!(visit_count: 0)

    assert_difference -> { thing.reload.visit_count }, 1 do
      Things::RecordVisit.call(thing: thing)
    end
  end
end
