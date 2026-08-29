# frozen_string_literal: true

require "test_helper"

class IntegrationTestGateway < Lipwa::Gateways::Mpesa
  configure do |c|
    c.env = :sandbox
    c.consumer_key = "test-consumer-key"
    c.consumer_secret = "test-consumer-secret"
    c.shortcode = "174379"
    c.passkey = "test-passkey"
  end
end

module Lipwa
  module Gateways
    # Drives the assembled Mpesa gateway (Auth + BearerToken strategy +
    # capability) through sanitized VCR cassettes of Daraja's sandbox
    # responses, instead of the fake-host WebMock stubs used by
    # stk_push_test.rb/c2b_test.rb — this covers the real OAuth ->
    # bearer-token -> capability request path CI never actually runs
    # against the live sandbox.
    class MpesaIntegrationTest < Minitest::Test
      include Dry::Monads[:result]

      def test_stk_push_success
        VCR.use_cassette("mpesa/stk_push_success") do
          result = IntegrationTestGateway.new.stk_push(**valid_stk_push_args)

          assert result.success?
          assert_equal "ws_CO_020120001010101010", result.value!.provider_reference
        end
      end

      def test_stk_push_surfaces_a_synchronous_daraja_error_in_the_response
        VCR.use_cassette("mpesa/stk_push_error") do
          result = IntegrationTestGateway.new.stk_push(**valid_stk_push_args)

          assert result.success?
          response = result.value!
          refute response.success?
          assert_equal "400.002.02", response.code
          assert_equal "Bad Request - Invalid ShortCode", response.message
        end
      end

      def test_register_urls_success
        VCR.use_cassette("mpesa/c2b_register_urls_success") do
          result = IntegrationTestGateway.new.register_urls(**valid_register_urls_args)

          assert result.success?
          assert_equal "12362-3240472-1", result.value!.provider_reference
        end
      end

      def test_simulate_success
        VCR.use_cassette("mpesa/c2b_simulate_success") do
          result = IntegrationTestGateway.new.simulate(**valid_simulate_args)

          assert result.success?
          assert_equal "AG_20180402_00004a92452ef78e864d", result.value!.provider_reference
        end
      end

      private

      def valid_stk_push_args
        {
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          phone_number: "254712345678",
          account_reference: "ORDER-123",
          callback_url: "https://example.com/webhooks/mpesa"
        }
      end

      def valid_register_urls_args
        {
          validation_url: "https://example.com/webhooks/mpesa/validate",
          confirmation_url: "https://example.com/webhooks/mpesa/confirm"
        }
      end

      def valid_simulate_args
        {
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          phone_number: "254712345678",
          bill_ref_number: "ORDER-123"
        }
      end
    end
  end
end
