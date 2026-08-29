# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Gateways
    class MpesaTest < Minitest::Test
      def teardown
        Mpesa.config.consumer_key = nil
        Mpesa.config.consumer_secret = nil
        Mpesa.config.shortcode = nil
        Mpesa.config.passkey = nil
        Mpesa.config.env = :sandbox
      end

      def test_missing_config_raises_configuration_error
        gateway = Mpesa.new

        assert_raises(Lipwa::ConfigurationError) { gateway.http }
      end

      def test_base_url_defaults_to_sandbox
        configure_mpesa
        gateway = Mpesa.new

        assert_equal "https://sandbox.safaricom.co.ke", gateway.http.base_url
      end

      def test_base_url_switches_to_production
        configure_mpesa(env: :production)
        gateway = Mpesa.new

        assert_equal "https://api.safaricom.co.ke", gateway.http.base_url
      end

      def test_capability_stk_push_is_registered
        configure_mpesa
        gateway = Mpesa.new

        assert gateway.capability?(:stk_push)
      end

      def test_registered_in_gateways_container
        assert_same Mpesa, Lipwa::Gateways[:mpesa].class
      end

      def test_stk_push_end_to_end_fetches_token_then_calls_through
        configure_mpesa

        stub_request(:get, "https://sandbox.safaricom.co.ke/oauth/v1/generate")
          .with(query: { grant_type: "client_credentials" })
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { access_token: "abc123", expires_in: "3599" }.to_json
          )
        stub_request(:post, "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest")
          .with { |req| req.headers["Authorization"] == "Bearer abc123" }
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { ResponseCode: "0", CheckoutRequestID: "ws_CO_123456789" }.to_json
          )

        result = Mpesa.new.stk_push(
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          phone_number: "254712345678",
          account_reference: "ORDER-123",
          callback_url: "https://example.com/webhooks/mpesa"
        )

        assert result.success?
        assert_equal "ws_CO_123456789", result.value!.provider_reference
      end

      private

      def configure_mpesa(env: :sandbox)
        Mpesa.configure do |c|
          c.env = env
          c.consumer_key = "key"
          c.consumer_secret = "secret"
          c.shortcode = "174379"
          c.passkey = "passkey"
        end
      end
    end
  end
end
