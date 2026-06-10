require "test_helper"

class PrinterTest < ActiveSupport::TestCase
  test "requires name, cups name, and page size" do
    printer = Printer.new
    assert_not printer.valid?
    assert_includes printer.errors[:name], "can't be blank"
    assert_includes printer.errors[:cups_name], "can't be blank"
    assert_includes printer.errors[:page_size], "can't be blank"
  end

  test "validates page size inclusion" do
    printer = printers(:label_printer)
    printer.page_size = "invalid"
    assert_not printer.valid?
  end

  test "page size metadata" do
    printer = printers(:shipping_printer)
    assert_equal '4×6" label', printer.page_size_label
    assert_equal "Label", printer.page_size_category
    assert_equal "4x6", printer.cups_media
  end

  test "supports all configured page sizes" do
    assert_equal %w[label_strip_24mm label_4x6 letter receipt_80mm], Printer::PAGE_SIZES.keys
  end
end
