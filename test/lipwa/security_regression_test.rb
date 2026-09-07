# frozen_string_literal: true

require "test_helper"

class SecurityRegressionTest < Minitest::Test
  UNSAFE_REFERENCES = ["known-ref/capture#", "../other", "..", ".", "ref?x=1", "ref%2fcapture", "ref\\capture"].freeze

  def test_card_operations_reject_url_syntax_before_sending_requests
    gateway = Lipwa::Gateways::Flutterwave.new
    UNSAFE_REFERENCES.each do |reference|
      result = gateway.void(authorization: reference)
      assert result.failure?, reference
      assert_instance_of Lipwa::ValidationError, result.failure
    end
  end

  def test_lightning_checks_reject_url_syntax_before_sending_requests
    gateway = Lipwa::Gateways::Lnbits.new
    UNSAFE_REFERENCES.each do |reference|
      %i[check_invoice check_payment].each do |operation|
        result = gateway.public_send(operation, payment_hash: reference)
        assert result.failure?, reference
        assert_instance_of Lipwa::ValidationError, result.failure
      end
    end
  end

  def test_configuration_inspection_redacts_provider_keys
    context = Lipwa::Context.new do |builder|
      builder.gateway(:lnbits) do |config|
        config.admin_key = "admin-credential"
        config.invoice_key = "invoice-credential"
      end
      builder.gateway(:flutterwave) { |config| config.encryption_key = "encryption-credential" }
    end

    refute_includes context.gateway(:lnbits).config.inspect, "admin-credential"
    refute_includes context.gateway(:lnbits).config.inspect, "invoice-credential"
    refute_includes context.gateway(:flutterwave).config.inspect, "encryption-credential"
  end

  def test_redacts_provider_keys_in_nested_payloads_and_urls
    %w[admin_key invoice_key encryption_key AdminKey Invoice-Key EncryptionKey].each do |key|
      redacted = Lipwa::Logging::Redactor.call({ "nested" => [{ key => "credential-value" }] })
      refute_includes redacted.inspect, "credential-value"
      refute_includes Lipwa::Logging::Redactor.call("https://example.com/?#{key}=credential-value"), "credential-value"
    end
  end

  def test_lnbits_rejects_blank_or_non_string_tokens
    [nil, "", " \t\n", 123].each do |token|
      refute Lipwa::Webhooks::Lnbits.verify_signature(expected_token: token, provided_token: token)
    end
  end

  def test_jenga_rejects_either_blank_credential
    ["", " \t\n"].each do |blank|
      [[blank, "secret"], ["user", blank], [blank, blank]].each do |username, password|
        authorization = "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
        refute Lipwa::Webhooks::Jenga.verify_signature(
          raw: {}, authorization: authorization, username: username, password: password
        )
      end
    end
  end
end
