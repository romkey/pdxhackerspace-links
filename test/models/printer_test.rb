require "test_helper"

class PrinterTest < ActiveSupport::TestCase
  test "requires name, cups server, cups name, and page size" do
    printer = Printer.new
    assert_not printer.valid?
    assert_includes printer.errors[:name], "can't be blank"
    assert_includes printer.errors[:cups_server], "can't be blank"
    assert_includes printer.errors[:cups_name], "can't be blank"
    assert_includes printer.errors[:page_size], "can't be blank"
  end

  test "validates page size inclusion" do
    printer = printers(:label_printer)
    printer.page_size = "invalid"
    assert_not printer.valid?
  end

  test "validates cups server format" do
    printer = printers(:label_printer)
    printer.cups_server = "not a valid server"
    assert_not printer.valid?
  end

  test "allows same cups name on different servers" do
    existing = printers(:label_printer)
    duplicate = Printer.new(
      name: "Remote copy",
      cups_server: "other.example.com:631",
      cups_name: existing.cups_name,
      page_size: "label_strip_24mm"
    )

    assert duplicate.valid?
  end

  test "rejects duplicate cups name on same server" do
    existing = printers(:label_printer)
    duplicate = Printer.new(
      name: "Duplicate queue",
      cups_server: existing.cups_server,
      cups_name: existing.cups_name,
      page_size: "label_strip_24mm"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:cups_name], "has already been taken"
  end

  test "brother label page size metadata" do
    printer = printers(:brother_printer)
    assert_equal "62mm continuous", printer.page_size_label
    assert_equal "Brother label", printer.page_size_group_label
    assert_equal "Custom.62x0mm", printer.cups_media
  end

  test "letter printer supports avery templates" do
    printer = printers(:office_laser)
    assert printer.supports_avery_templates?
    assert_equal "Avery 5160", printer.avery_template_label
  end

  test "avery template requires letter page size" do
    printer = printers(:brother_printer)
    printer.avery_template = "avery_5160"
    assert_not printer.valid?
    assert_includes printer.errors[:avery_template], "is only supported for letter page size"
  end

  test "includes brother label sizes" do
    brother_sizes = Printer::PAGE_SIZES.select { |_key, config| config[:group] == "brother_label" }.keys
    assert_includes brother_sizes, "label_brother_62mm"
    assert_includes brother_sizes, "label_brother_62x100"
  end

  test "command printer requires height and print command with filename placeholder" do
    printer = Printer.new(
      name: "Script printer",
      printer_type: "command",
      print_command: "echo missing placeholder",
      enabled: true
    )

    assert_not printer.valid?
    assert_includes printer.errors[:label_height_mm], "can't be blank"
    assert_includes printer.errors[:print_command], "must include FILENAME"

    printer.label_height_mm = 24
    printer.print_command = "echo FILENAME"
    assert printer.valid?
  end

  test "command printer does not require cups fields" do
    printer = printers(:command_printer)
    assert printer.valid?
    assert_nil printer.cups_server
    assert_nil printer.page_size
  end
end
