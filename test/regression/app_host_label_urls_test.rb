require "test_helper"

class AppHostLabelUrlsRegressionTest < ActiveSupport::TestCase
  REGRESSION_HOST = "https://links.regression.test"
  SHORT_HOST = "http://l.regression"

  test "label thing url uses SHORT_URL_HOST and thing key" do
    with_short_url_host(SHORT_HOST) do
      thing = things(:router)
      url = label_pdf_for(thing).send(:thing_url)

      assert_equal "#{SHORT_HOST}/#{thing.key}?utm_source=qrcode", url
      assert_not_includes url, "example.com"
      assert_not_includes url, "/things/"
    end
  end

  test "label qr png encodes short url host and thing key" do
    with_short_url_host(SHORT_HOST) do
      thing = things(:router)
      encoded_url = capture_qr_payload do
        label_pdf_for(thing).send(:qr_png_data, 72)
      end

      assert_equal "#{SHORT_HOST}/#{thing.key}?utm_source=qrcode", encoded_url
      assert_not_includes encoded_url, "example.com"
      assert_not_includes encoded_url, "/things/"
    end
  end

  test "nfc tag url uses SHORT_URL_HOST and thing key" do
    with_short_url_host(SHORT_HOST) do
      thing = things(:router)
      result = Things::NfcTagPayload.call(thing)

      assert_equal "#{SHORT_HOST}/#{thing.key}?utm_source=nfc", result.url
      assert_not_includes result.url, "example.com"
      assert_not_includes result.url, "/things/"
      assert_equal result.url, JSON.parse(result.json)["url"]
    end
  end

  test "printer test label passes APP_HOST root url to label pdf" do
    with_app_host(REGRESSION_HOST) do
      printer = printers(:brother_printer)
      captured = {}

      stub_label_pdf_initializer(captured) do
        client = spy_cups_client

        Printers::PrintTestLabel.call(printer: printer, cups_client: client)
      end

      assert_equal "#{REGRESSION_HOST}/", captured[:qr_url]
      assert_not_includes captured[:qr_url], "example.com"
    end
  end

  test "custom qr_url override is preserved on labels" do
    thing = things(:keyboard)
    custom_url = "https://custom.example.org/#{thing.key}"
    label_pdf = Things::LabelPdf.new(
      thing: thing,
      printer: printers(:brother_printer),
      qr_url: custom_url
    )

    assert_equal custom_url, label_pdf.send(:thing_url)
  end

  test "label qr url updates when SHORT_URL_HOST changes" do
    thing = things(:router)
    label_pdf = label_pdf_for(thing)

    old_url = with_short_url_host("http://old.regression") do
      label_pdf.send(:thing_url)
    end

    new_url = with_short_url_host("http://new.regression") do
      label_pdf.send(:thing_url)
    end

    assert_equal "http://old.regression/#{thing.key}?utm_source=qrcode", old_url
    assert_equal "http://new.regression/#{thing.key}?utm_source=qrcode", new_url
  end

  private

  def label_pdf_for(thing)
    Things::LabelPdf.new(thing: thing, printer: printers(:label_printer))
  end

  def capture_qr_payload
    captured = nil
    original = RQRCode::QRCode.method(:new)

    RQRCode::QRCode.singleton_class.send(:define_method, :new) do |data, **options|
      captured = data
      original.call(data, **options)
    end

    yield
    captured
  ensure
    RQRCode::QRCode.singleton_class.send(:define_method, :new, original) if original
  end

  def stub_label_pdf_initializer(captured)
    original = Things::LabelPdf.method(:new)

    Things::LabelPdf.singleton_class.send(:define_method, :new) do |**kwargs|
      captured.merge!(kwargs)
      original.call(**kwargs)
    end

    yield
  ensure
    Things::LabelPdf.singleton_class.send(:define_method, :new, original) if original
  end

  def spy_cups_client
    runner = lambda do |*_args|
      case _args[1]
      when "lp" then [ "request id is Brother-1 (1 file(s))\n", "", Struct.new(:success?).new(true) ]
      when "lpstat" then [ "", "", Struct.new(:success?).new(true) ]
      else [ "", "", Struct.new(:success?).new(false) ]
      end
    end

    Cups::Client.new(server: printers(:brother_printer).cups_server, runner: runner)
  end
end
