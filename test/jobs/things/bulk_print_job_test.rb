require "test_helper"

class Things::BulkPrintJobTest < ActiveJob::TestCase
  test "prints each thing and marks labelled when requested" do
    printer = printers(:brother_printer)
    thing = things(:keyboard)

    with_fake_cups_client do
      Things::BulkPrintJob.perform_now(
        thing_ids: [ thing.id ],
        printer_id: printer.id,
        layout: "standard",
        copies: 1,
        mark_labelled: true
      )
    end

    assert thing.reload.labelled?
  end

  test "continues when one thing fails to print" do
    with_fake_cups_client do
      assert_nothing_raised do
        Things::BulkPrintJob.perform_now(
          thing_ids: [ things(:keyboard).id ],
          printer_id: printers(:label_printer).id,
          layout: "cable_tag",
          mark_labelled: true
        )
      end
    end

    assert_not things(:keyboard).reload.labelled?
  end
end
