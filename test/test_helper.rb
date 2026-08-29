# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "lipwa"

require "base64"
require "minitest/autorun"
require "webmock/minitest"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = { record: :none }

  # Cassettes are hand-authored with fake sandbox credentials/tokens, so
  # these filters are a no-op today — they only matter if someone ever
  # re-records a cassette locally against a real sandbox account
  # (record: :once). They scrub the Basic-auth header and access token
  # before anything hits disk, so a real secret can't accidentally get
  # committed.
  config.filter_sensitive_data("<MPESA_BASIC_AUTH>") do
    "Basic #{Base64.strict_encode64("test-consumer-key:test-consumer-secret")}"
  end
  config.filter_sensitive_data("<MPESA_ACCESS_TOKEN>") { "SANDBOX-TEST-ACCESS-TOKEN" }
end

WebMock.disable_net_connect!(allow_localhost: true)
