# frozen_string_literal: true

require_relative "../gateway"
require_relative "../gateways"
require_relative "../capabilities/purchase"
require_relative "../capabilities/authorize"
require_relative "../capabilities/capture"
require_relative "../capabilities/void"

module Lipwa
  module Gateways
    # Paystack hosted card payments. Paystack captures card payments in its
    # checkout flow, so capture verifies the transaction and void refunds it.
    class Paystack < Lipwa::Gateway
      include Lipwa::Capabilities::Purchase
      include Lipwa::Capabilities::Authorize
      include Lipwa::Capabilities::Capture
      include Lipwa::Capabilities::Void

      BASE_URL = "https://api.paystack.co"
      INITIALIZE_PATH = "/transaction/initialize"
      VERIFY_PATH = "/transaction/verify"
      REFUND_PATH = "/refund"
      SUBUNIT_FACTOR = 100

      setting :secret_key

      private

      def perform_purchase(params, idempotency_key) = initialize_transaction(params, idempotency_key)
      def perform_authorize(params, idempotency_key) = initialize_transaction(params, idempotency_key)

      def perform_capture(params, idempotency_key)
        response = http.get("#{VERIFY_PATH}/#{params[:authorization]}", idempotency_key: idempotency_key)
        build_response(response.body, fallback_reference: params[:authorization], require_completed: true)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def perform_void(params, idempotency_key)
        response = http.post(REFUND_PATH, body: { transaction: params[:authorization] },
                                          idempotency_key: idempotency_key)
        build_response(response.body, fallback_reference: params[:authorization])
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def initialize_transaction(params, idempotency_key)
        email = address_value(params[:billing_address], :email_address)
        return Failure(Lipwa::GatewayError.new("billing_address email_address is required by Paystack")) unless email

        response = http.post(INITIALIZE_PATH, body: initialize_body(params, email),
                                              idempotency_key: idempotency_key)
        build_response(response.body, fallback_reference: params[:reference])
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def initialize_body(params, email)
        {
          email: email,
          amount: paystack_amount(params[:amount]),
          currency: params[:amount].currency,
          reference: params[:reference],
          callback_url: params[:callback_url],
          channels: ["card"],
          metadata: { description: params[:description], notification_id: params[:notification_id] }
        }
      end

      def paystack_amount(money)
        subunits = money.amount * SUBUNIT_FACTOR
        raise Lipwa::GatewayError, "amount must resolve to a whole Paystack subunit" unless subunits.frac.zero?

        subunits.to_i
      end

      def address_value(address, key) = address[key] || address[key.to_s]

      def build_response(body, fallback_reference:, require_completed: false)
        data = body["data"].is_a?(Hash) ? body["data"] : {}
        Success(Lipwa::Response.new(
                  success: response_successful?(body, data, require_completed),
                  provider_reference: (data["reference"] || fallback_reference)&.to_s,
                  message: body["message"] || data["status"],
                  code: (data["status"] || body["status"])&.to_s,
                  raw: body
                ))
      end

      def response_successful?(body, data, require_completed)
        return false unless body["status"] == true
        return true unless require_completed

        data["status"].to_s.casecmp?("success")
      end

      # rubocop:disable Metrics/AbcSize
      def build_http_adapter
        config = self.class.config
        ensure_paystack_config_present!(config)
        auth = config.auth_strategy || AuthStrategies::BearerToken.new(-> { config.secret_key })
        HttpAdapter.new(base_url: config.base_url || BASE_URL, auth_strategy: auth,
                        timeout: config.timeout || Lipwa.config.default_timeout,
                        open_timeout: config.open_timeout, logger: config.logger || Lipwa.config.logger,
                        adapter: Lipwa.config.adapter)
      end
      # rubocop:enable Metrics/AbcSize

      def ensure_paystack_config_present!(config)
        return if config.auth_strategy || config.secret_key

        raise Lipwa::ConfigurationError, "#{self.class} is missing secret_key — set it via .configure"
      end
    end
  end
end

Lipwa::Gateways.register(:paystack, Lipwa::Gateways::Paystack)
