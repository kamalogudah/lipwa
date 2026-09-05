# frozen_string_literal: true

Lipwa.configure do |config|
  config.logger = Rails.logger
  config.default_timeout = 10
end

Lipwa::Gateways::Jenga.configure do |c|
  c.env = ENV.fetch("JENGA_ENV", "sandbox").to_sym
  c.api_key = ENV["JENGA_API_KEY"]
  c.merchant_code = ENV["JENGA_MERCHANT_CODE"]
  c.consumer_secret = ENV["JENGA_CONSUMER_SECRET"]
  c.private_key = File.read(ENV["JENGA_PRIVATE_KEY_PATH"]) if ENV["JENGA_PRIVATE_KEY_PATH"].present?
  c.source_account = ENV["JENGA_SOURCE_ACCOUNT"]
  c.source_name = ENV["JENGA_SOURCE_NAME"]
  c.country_code = ENV.fetch("JENGA_COUNTRY_CODE", "KE")
  c.partner_id = ENV["JENGA_PARTNER_ID"]
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
