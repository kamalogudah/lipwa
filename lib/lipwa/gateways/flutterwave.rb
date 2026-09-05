# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require_relative "../gateway"
require_relative "../gateways"
require_relative "../capabilities/purchase"
require_relative "../capabilities/authorize"
require_relative "../capabilities/capture"
require_relative "../capabilities/void"

module Lipwa
  module Gateways
    # Flutterwave v3 hosted payments and preauthorized card charges.
    # rubocop:disable Metrics/ClassLength
    class Flutterwave < Lipwa::Gateway
      include Lipwa::Capabilities::Purchase
      include Lipwa::Capabilities::Authorize
      include Lipwa::Capabilities::Capture
      include Lipwa::Capabilities::Void

      BASE_URL = "https://api.flutterwave.com"
      PAYMENTS_PATH = "/v3/payments"
      CHARGES_PATH = "/v3/charges"

      setting :secret_key
      setting :encryption_key

      private

      def perform_purchase(params, idempotency_key)
        response = http.post(PAYMENTS_PATH, body: hosted_payment_body(params), idempotency_key: idempotency_key)
        build_flutterwave_response(response.body, fallback_reference: params[:reference])
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def perform_authorize(params, idempotency_key)
        missing = %i[card_number cvv expiry_month expiry_year].reject { |key| params[key] }
        return missing_card_failure(missing) unless missing.empty?

        return missing_encryption_key_failure unless config.encryption_key

        response = http.post(CHARGES_PATH, params: { type: "card" },
                                           body: encrypted_card_body(params), idempotency_key: idempotency_key)
        build_flutterwave_response(response.body, fallback_reference: params[:reference])
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def perform_capture(params, idempotency_key)
        unless params[:amount]
          return Failure(Lipwa::GatewayError.new("amount is required to capture a Flutterwave charge"))
        end

        response = http.post(charge_path(params[:authorization], "capture"),
                             body: { amount: params[:amount].amount }, idempotency_key: idempotency_key)
        build_flutterwave_response(response.body, fallback_reference: params[:authorization])
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def perform_void(params, idempotency_key)
        response = http.post(charge_path(params[:authorization], "void"), body: {},
                                                                          idempotency_key: idempotency_key)
        build_flutterwave_response(response.body, fallback_reference: params[:authorization])
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      # rubocop:disable Metrics/MethodLength
      def hosted_payment_body(params)
        address = params[:billing_address]
        {
          tx_ref: params[:reference], amount: params[:amount].amount, currency: params[:amount].currency,
          redirect_url: params[:callback_url], payment_options: "card",
          customer: {
            email: address_value(address, :email_address),
            phonenumber: address_value(address, :phone_number),
            name: params[:fullname] || customer_name(address)
          }.compact,
          customizations: { title: params[:description], description: params[:description] }
        }
      end

      # rubocop:enable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      def card_charge_body(params)
        address = params[:billing_address]
        {
          card_number: params[:card_number], cvv: params[:cvv], expiry_month: params[:expiry_month],
          expiry_year: params[:expiry_year], amount: params[:amount].amount,
          currency: params[:amount].currency, email: address_value(address, :email_address),
          fullname: params[:fullname] || customer_name(address),
          phone_number: params[:phone_number] || address_value(address, :phone_number),
          tx_ref: params[:reference], redirect_url: params[:callback_url],
          preauthorize: true, usesecureauth: params.fetch(:usesecureauth, true)
        }.compact
      end

      def encrypted_card_body(params)
        cipher = OpenSSL::Cipher.new("des-ede3")
        cipher.encrypt
        cipher.key = config.encryption_key
        encrypted = cipher.update(JSON.generate(card_charge_body(params))) + cipher.final
        { client: Base64.strict_encode64(encrypted) }
      end

      # rubocop:enable Metrics/AbcSize
      def customer_name(address)
        name = [address_value(address, :first_name), address_value(address, :last_name)].compact.join(" ")
        name unless name.empty?
      end

      def address_value(address, key) = address[key] || address[key.to_s]
      def charge_path(reference, operation) = "#{CHARGES_PATH}/#{reference}/#{operation}"

      def build_flutterwave_response(body, fallback_reference:)
        data = body["data"].is_a?(Hash) ? body["data"] : {}
        Success(Lipwa::Response.new(
                  success: body["status"] == "success",
                  provider_reference: (data["flw_ref"] || data["id"] || fallback_reference)&.to_s,
                  message: body["message"] || data["processor_response"],
                  code: body["status"]&.to_s,
                  raw: body
                ))
      end

      def missing_card_failure(missing)
        Failure(Lipwa::GatewayError.new("missing #{missing.join(", ")}"))
      end

      def missing_encryption_key_failure
        Failure(Lipwa::GatewayError.new("encryption_key is required to authorize a Flutterwave card"))
      end

      # rubocop:disable Metrics/AbcSize
      def build_http_adapter
        config = self.config
        ensure_flutterwave_config_present!(config)
        auth = config.auth_strategy || AuthStrategies::BearerToken.new(-> { config.secret_key })
        HttpAdapter.new(base_url: config.base_url || BASE_URL, auth_strategy: auth,
                        timeout: config.timeout || global_config.default_timeout,
                        open_timeout: config.open_timeout, logger: config.logger || global_config.logger,
                        adapter: global_config.adapter)
      end
      # rubocop:enable Metrics/AbcSize

      def ensure_flutterwave_config_present!(config)
        return if config.auth_strategy || config.secret_key

        raise Lipwa::ConfigurationError, "#{self.class} is missing secret_key — set it via .configure"
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength
Lipwa::Gateways.register(:flutterwave, Lipwa::Gateways::Flutterwave)
