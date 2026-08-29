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

# A throwaway self-signed cert, generated once per test run, standing in
# for Safaricom's public B2C/B2B cert so Disbursement/SecurityCredential
# specs can encrypt without needing a real Daraja certificate on disk.
TEST_MPESA_CERT = begin
  key = OpenSSL::PKey::RSA.new(2048)
  name = OpenSSL::X509::Name.parse("/CN=lipwa-test")
  cert = OpenSSL::X509::Certificate.new
  cert.version = 2
  cert.serial = 1
  cert.subject = name
  cert.issuer = name
  cert.public_key = key.public_key
  cert.not_before = Time.now
  cert.not_after = Time.now + 3600
  cert.sign(key, OpenSSL::Digest.new("SHA256"))
  cert.to_pem
end.freeze
