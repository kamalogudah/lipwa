# frozen_string_literal: true

require "securerandom"
require "date"
require "json"
require_relative "../gateway"
require_relative "../gateways"
require_relative "../capabilities/bank_transfer"
require_relative "../capabilities/disbursement"

module Lipwa
  module Gateways
    # Equity/Finserve Jenga HQ gateway.
    class Jenga < Lipwa::Gateway
      include Lipwa::Capabilities::BankTransfer
      include Lipwa::Capabilities::Disbursement

      BASE_URLS = {
        sandbox: "https://uat.finserve.africa/v3-apis",
        production: "https://api.finserve.africa/v3-apis"
      }.freeze
      TOKEN_URLS = {
        sandbox: "https://uat.finserve.africa/authentication/api/v3/authenticate/merchant",
        production: "https://api.finserve.africa/authentication/api/v3/authenticate/merchant"
      }.freeze
      PATHS = {
        internal: "/transaction-api/v3.0/remittance/internalBankTransfer",
        pesalink: "/transaction-api/v3.0/remittance/pesalinkacc",
        rtgs: "/transaction-api/v3.0/remittance/rtgs",
        swift: "/transaction-api/v3.0/remittance/swift",
        mobile: "/transaction-api/v3.0/remittance/sendmobile",
        bill_payment: "/transaction-api/v3.0/bills/pay",
        balance: "/account-api/v3.0/accounts/balances",
        statement: "/account-api/v3.0/accounts/fullStatement",
        forex: "/transaction-api/v3.0/foreignexchangerates"
      }.freeze
      TRANSFER_TYPES = {
        internal: "EFT", pesalink: "PesaLink", rtgs: "RTGS", swift: "SWIFT"
      }.freeze

      setting :api_key
      setting :merchant_code
      setting :consumer_secret
      setting :private_key
      setting :source_account
      setting :source_name
      setting :country_code, default: "KE"
      setting :partner_id
      setting :token_url
      setting :clock

      def forex_rates(currency_code:, amount:, to_currency:, country_code: nil, idempotency_key: nil)
        body = {
          countryCode: country_code || config.country_code,
          currencyCode: currency_code,
          amount: format_amount(amount),
          toCurrency: to_currency
        }
        response = http.post(PATHS[:forex], body: body, idempotency_key: idempotency_key)
        build_jenga_response(response.body)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      private

      def build_http_adapter
        config = self.config
        ensure_jenga_config_present!(config)
        auth_strategy = config.auth_strategy || AuthStrategies::Jenga.new(
          token_provider: Auth.new(
            api_key: config.api_key,
            merchant_code: config.merchant_code,
            consumer_secret: config.consumer_secret,
            token_url: config.token_url || TOKEN_URLS.fetch(config.env)
          ),
          private_key: config.private_key,
          signature_payload: method(:signature_payload)
        )

        HttpAdapter.new(
          base_url: config.base_url || BASE_URLS.fetch(config.env),
          auth_strategy: auth_strategy,
          timeout: config.timeout || global_config.default_timeout,
          open_timeout: config.open_timeout,
          logger: config.logger || global_config.logger,
          adapter: global_config.adapter
        )
      end

      def ensure_jenga_config_present!(config)
        required = %i[source_account source_name]
        required.concat(%i[api_key merchant_code consumer_secret private_key]) unless config.auth_strategy
        missing = required.reject { |name| config.public_send(name) }
        return if missing.empty?

        raise Lipwa::ConfigurationError,
              "#{self.class} is missing #{missing.join("/")} — set them via .configure"
      end

      def bank_transfer_request(params, idempotency_key)
        path = PATHS.fetch(params[:rail])
        body = params[:rail] == :bill_payment ? bill_payment_body(params) : bank_transfer_body(params)
        http.post(path, body: body, idempotency_key: idempotency_key)
      end

      def bank_balance_request(params, idempotency_key)
        country = config.country_code
        http.get("#{PATHS[:balance]}/#{country}/#{params[:account_number]}", idempotency_key: idempotency_key)
      end

      def bank_statement_request(params, idempotency_key)
        date = request_date
        body = {
          countryCode: config.country_code,
          accountNumber: params[:account_number],
          fromDate: (params[:from_date] || date).iso8601,
          toDate: (params[:to_date] || date).iso8601
        }
        http.post(PATHS[:statement], body: body, idempotency_key: idempotency_key)
      end

      def bank_transfer_body(params)
        {
          source: source_payload(params[:source_account]),
          destination: {
            type: "bank",
            countryCode: config.country_code,
            name: params[:destination_name],
            accountNumber: params[:destination_account],
            bankCode: params[:destination_bank_code]
          }.compact,
          transfer: transfer_payload(params, TRANSFER_TYPES.fetch(params[:rail]))
        }
      end

      def bill_payment_body(params)
        {
          biller: {
            billerCode: params[:biller_code],
            countryCode: config.country_code
          },
          bill: {
            reference: params[:destination_account],
            amount: format_amount(params[:amount].amount),
            currency: params[:amount].currency
          },
          payer: {
            name: config.source_name,
            accountNumber: params[:source_account],
            reference: params[:reference]
          },
          partnerId: config.partner_id || config.merchant_code
        }
      end

      def transfer_payload(params, type)
        {
          type: type,
          amount: format_amount(params[:amount].amount),
          currencyCode: params[:amount].currency,
          reference: params[:reference],
          date: request_date.iso8601,
          description: params[:narration] || params[:reference],
          callbackUrl: params[:callback_url]
        }.compact
      end

      # Provider-specific implementation behind the shared Disbursement API.
      def perform_disburse(params, idempotency_key)
        response = http.post(PATHS[:mobile], body: mobile_money_body(params), idempotency_key: idempotency_key)
        build_jenga_response(response.body)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def ensure_disbursement_config_present!
        ensure_jenga_config_present!(config)
      end

      def mobile_money_body(params)
        reference = params[:account_reference] || params[:occasion] || SecureRandom.uuid
        {
          source: source_payload(config.source_account),
          destination: {
            type: "mobile",
            countryCode: config.country_code,
            name: params[:party_b],
            mobileNumber: params[:party_b],
            walletName: "Mpesa"
          },
          transfer: {
            type: "MobileWallet",
            amount: format_amount(params[:amount].amount),
            currencyCode: params[:amount].currency,
            reference: reference,
            date: request_date.iso8601,
            description: params[:remarks],
            callbackUrl: params[:result_url]
          }
        }
      end

      def source_payload(account)
        {
          countryCode: config.country_code,
          name: config.source_name,
          accountNumber: account
        }
      end

      def signature_payload(env)
        body = env.body.to_s.empty? ? {} : JSON.parse(env.body)
        path = env.url.path
        case path
        when /sendmobile\z/
          join_fields(body, %w[transfer.amount transfer.currencyCode transfer.reference source.accountNumber])
        when /internalBankTransfer\z/
          join_fields(body, %w[source.accountNumber transfer.amount transfer.currencyCode transfer.reference])
        when /pesalinkacc\z/
          join_fields(body,
                      %w[transfer.amount transfer.currencyCode transfer.reference destination.name
                         source.accountNumber])
        when /(?:rtgs|swift)\z/
          join_fields(body,
                      %w[transfer.reference transfer.date source.accountNumber destination.accountNumber
                         transfer.amount])
        when %r{bills/pay\z}
          join_fields(body, %w[biller.billerCode bill.amount payer.reference partnerId])
        when /fullStatement\z/
          join_fields(body, %w[accountNumber countryCode toDate])
        when /foreignexchangerates\z/
          join_fields(body, %w[countryCode currencyCode amount toCurrency])
        when %r{accounts/balances/([^/]+)/([^/]+)\z}
          "#{Regexp.last_match(1)}#{Regexp.last_match(2)}"
        else
          raise Lipwa::ConfigurationError, "no Jenga signature formula for #{path}"
        end
      end

      def join_fields(body, fields)
        fields.map do |field|
          field.split(".").reduce(body) { |value, key| value.fetch(key) }
        end.join
      rescue KeyError => e
        raise Lipwa::ConfigurationError, "missing Jenga signature field: #{e.key}"
      end

      def build_bank_response(body) = build_jenga_response(body)

      def build_jenga_response(body)
        data = body["data"].is_a?(Hash) ? body["data"] : {}
        code = body["code"] || body["statusCode"] || data["code"]
        reference = body["reference"] || body["transactionId"] ||
                    data["reference"] || data["transactionId"]
        message = body["message"] || body["description"] || data["message"]
        success = body["status"] != false && (code.nil? || %w[0 00 200 201 SUCCESS Success].include?(code.to_s))
        Success(Lipwa::Response.new(
                  success: success,
                  provider_reference: reference&.to_s,
                  message: message&.to_s,
                  code: code&.to_s,
                  raw: body
                ))
      end

      def request_date
        value = config.clock&.call || Date.today
        value.respond_to?(:to_date) ? value.to_date : value
      end

      def format_amount(value)
        format("%.2f", value)
      end
    end
  end
end

require_relative "jenga/auth"
Lipwa::Gateways.register(:jenga, Lipwa::Gateways::Jenga)
