# frozen_string_literal: true

Lipwa.configure do |config|
  config.logger = Rails.logger
  config.default_timeout = 10
end

Lipwa::Gateways::Mpesa.configure do |c|
  c.env = ENV.fetch("MPESA_ENV", "sandbox").to_sym
  c.consumer_key = ENV["MPESA_CONSUMER_KEY"]
  c.consumer_secret = ENV["MPESA_CONSUMER_SECRET"]
  c.shortcode = ENV["MPESA_SHORTCODE"]
  c.passkey = ENV["MPESA_PASSKEY"]

  # Only needed for #disburse and #refund:
  c.initiator_name = ENV["MPESA_INITIATOR_NAME"]
  c.initiator_password = ENV["MPESA_INITIATOR_PASSWORD"]
  c.security_credential_cert = File.read(ENV["MPESA_CERT_PATH"]) if ENV["MPESA_CERT_PATH"].present?
end
