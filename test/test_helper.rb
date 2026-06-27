ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  fixtures :all

  def sign_in_as(user)
    with_local_auth(email: user.email, password: "secret") do
      post local_login_path, params: { email: user.email, password: "secret" }
    end
  end

  def with_local_auth(email:, password: "secret")
    previous = %w[LOCAL_AUTH_EMAIL LOCAL_AUTH_PASSWORD LOCAL_AUTH_NAME].index_with { |key| ENV[key] }
    ENV["LOCAL_AUTH_EMAIL"] = email
    ENV["LOCAL_AUTH_PASSWORD"] = password
    ENV["LOCAL_AUTH_NAME"] = "Test User"
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  def with_fake_cups_client(server: "cups.example.com:631", fail_print: false, &block)
    runner = lambda do |*_args|
      case _args[1]
      when "lp"
        if fail_print
          [ "", "lp: unable to connect", Struct.new(:success?).new(false) ]
        else
          [ "request id is Test-1 (1 file(s))\n", "", Struct.new(:success?).new(true) ]
        end
      when "lpstat"
        [ "", "", Struct.new(:success?).new(true) ]
      else
        [ "", "", Struct.new(:success?).new(false) ]
      end
    end
    client = Cups::Client.new(server: server, runner: runner)
    patches = [
      [ Things::PrintLabel, :call ],
      [ Printers::PrintTestLabel, :call ]
    ].map do |klass, method_name|
      original = klass.method(method_name)
      klass.define_singleton_method(method_name) do |**kwargs|
        original.call(**kwargs, cups_client: kwargs.fetch(:cups_client, client))
      end
      [ klass, method_name, original ]
    end

    yield client
  ensure
    patches&.each do |klass, method_name, original|
      klass.define_singleton_method(method_name, original)
    end
  end
end
