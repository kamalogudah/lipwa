# frozen_string_literal: true

require_relative "../gateway"
require_relative "../gateways"
require_relative "../capabilities/purchase"
require_relative "../capabilities/authorize"
require_relative "../capabilities/capture"
require_relative "../capabilities/void"

module Lipwa
  module Gateways
    # Pesapal API 3.0 hosted-checkout gateway.
    class Pesapal < Lipwa::Gateway
      include Lipwa::Capabilities::Purchase
      include Lipwa::Capabilities::Authorize
      include Lipwa::Capabilities::Capture
      include Lipwa::Capabilities::Void

      BASE_URLS = {
        sandbox: "https://cybqa.pesapal.com/pesapalv3",
        production: "https://pay.pesapal.com/v3"
      }.freeze
      SUBMIT_ORDER_PATH = "/api/Transactions/SubmitOrderRequest"
      STATUS_PATH = "/api/Transactions/GetTransactionStatus"
      CANCEL_PATH = "/api/Transactions/CancelOrder"

      setting :consumer_key
      setting :consumer_secret
      setting :clock

      private

      def perform_purchase(params, idempotency_key) = submit_order(params, idempotency_key)
      def perform_authorize(params, idempotency_key) = submit_order(params, idempotency_key)

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def perform_capture(params, idempotency_key)
        response = http.get(STATUS_PATH, params: { orderTrackingId: params[:authorization] },
                                         idempotency_key: idempotency_key)
        body = response.body
        completed = body["payment_status_description"].to_s.casecmp?("COMPLETED") ||
                    body["status_code"].to_i == 1
        Success(Lipwa::Response.new(
                  success: completed,
                  provider_reference: body["confirmation_code"] || params[:authorization],
                  message: body["payment_status_description"] || pesapal_message(body),
                  code: (body["status_code"] || body["status"])&.to_s,
                  raw: body
                ))
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
      def perform_void(params, idempotency_key)
        response = http.post(CANCEL_PATH, body: { order_tracking_id: params[:authorization] },
                                          idempotency_key: idempotency_key)
        build_response(response.body, fallback_reference: params[:authorization])
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def submit_order(params, idempotency_key)
        response = http.post(SUBMIT_ORDER_PATH, body: order_body(params), idempotency_key: idempotency_key)
        build_response(response.body)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def order_body(params)
        {
          id: params[:reference], currency: params[:amount].currency, amount: params[:amount].amount,
          description: params[:description], callback_url: params[:callback_url],
          notification_id: params[:notification_id], billing_address: params[:billing_address],
          cancellation_url: params[:cancellation_url], redirect_mode: params[:redirect_mode],
          branch: params[:branch]
        }.compact
      end

      def build_response(body, fallback_reference: nil)
        status = body["status"].to_s
        error = pesapal_error(body)
        Success(Lipwa::Response.new(
                  success: error.empty? && status.start_with?("2"),
                  provider_reference: body["order_tracking_id"] || fallback_reference,
                  message: body["message"] || error["message"],
                  code: status.empty? ? error["code"]&.to_s : status,
                  raw: body
                ))
      end

      def pesapal_error(body) = body["error"].is_a?(Hash) ? body["error"] : {}
      def pesapal_message(body) = pesapal_error(body)["message"]

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def build_http_adapter
        config = self.config
        ensure_pesapal_config_present!(config)
        base_url = config.base_url || BASE_URLS.fetch(config.env)
        auth = config.auth_strategy || AuthStrategies::BearerToken.new(
          Auth.new(consumer_key: config.consumer_key, consumer_secret: config.consumer_secret,
                   base_url: base_url, clock: config.clock || -> { Time.now })
        )
        HttpAdapter.new(base_url: base_url, auth_strategy: auth,
                        timeout: config.timeout || global_config.default_timeout,
                        open_timeout: config.open_timeout, logger: config.logger || global_config.logger,
                        adapter: global_config.adapter)
      end

      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
      def ensure_pesapal_config_present!(config)
        return if config.auth_strategy || (config.consumer_key && config.consumer_secret)

        raise Lipwa::ConfigurationError,
              "#{self.class} is missing consumer_key/consumer_secret — set them via .configure"
      end
    end
  end
end

require_relative "pesapal/auth"

Lipwa::Gateways.register(:pesapal, Lipwa::Gateways::Pesapal)
