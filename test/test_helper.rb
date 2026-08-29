# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "lipwa"

require "minitest/autorun"
require "webmock/minitest"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = { record: :none }
end

WebMock.disable_net_connect!(allow_localhost: true)
