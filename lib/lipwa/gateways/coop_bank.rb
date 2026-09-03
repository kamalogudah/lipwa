# frozen_string_literal: true

require "securerandom"
require_relative "../gateway"
require_relative "../gateways"
require_relative "../capabilities/bank_transfer"
module Lipwa
  module Gateways
    class CoopBank < Lipwa::Gateway
      include Lipwa::Capabilities::BankTransfer
      BASE_URLS = { sandbox: "https://developer.co-opbank.co.ke:8243",
                    production: "https://developer.co-opbank.co.ke:8243" }.freeze
      TOKEN_URLS = BASE_URLS.transform_values { |url| "#{url}/token" }.freeze
      PATHS = { internal: "/FundsTransfer/Internal/A2A/2.0.0", rtgs: "/FundsTransfer/External/A2A/2.0.0",
                pesalink: "/FundsTransfer/External/A2M/2.0.0", bill_payment: "/BillPayment/PayBill/1.0.0",
                balance: "/Enquiry/AccountBalance/1.0.0", statement: "/Enquiry/MiniStatement/1.0.0" }.freeze
      setting :client_id
      setting :client_secret
      setting :token_url

      private

      def build_http_adapter
        config = self.class.config
        unless config.client_id && config.client_secret
          raise Lipwa::ConfigurationError,
                "#{self.class} is missing client_id/client_secret — set them via .configure"
        end

        auth = Auth.new(client_id: config.client_id, client_secret: config.client_secret,
                        token_url: config.token_url || TOKEN_URLS.fetch(config.env))
        HttpAdapter.new(base_url: config.base_url || BASE_URLS.fetch(config.env),
                        auth_strategy: AuthStrategies::BearerToken.new(auth),
                        timeout: config.timeout || Lipwa.config.default_timeout,
                        open_timeout: config.open_timeout, logger: config.logger || Lipwa.config.logger,
                        adapter: Lipwa.config.adapter)
      end

      def bank_transfer_request(params) = http.post(PATHS.fetch(params[:rail]), body: transfer_body(params))
      def bank_balance_request(params) = http.post(PATHS[:balance], body: inquiry_body(params))

      def bank_statement_request(params)
        body = inquiry_body(params)
        body[:StartDate] = params[:from_date].iso8601 if params[:from_date]
        body[:EndDate] = params[:to_date].iso8601 if params[:to_date]
        http.post(PATHS[:statement], body: body)
      end

      def transfer_body(params)
        common = { MessageReference: params[:reference], CallBackUrl: params[:callback_url] }.compact
        if params[:rail] == :bill_payment
          return common.merge(AccountNumber: params[:source_account], BillerCode: params[:biller_code],
                              BillAccountNumber: params[:destination_account], Amount: params[:amount].amount, Currency: params[:amount].currency, Narration: params[:narration] || params[:reference])
        end

        common.merge(Source: account_payload(params[:source_account], params),
                     Destinations: [account_payload(params[:destination_account], params).merge(
                       ReferenceNumber: params[:reference], BankCode: params[:destination_bank_code], BeneficiaryName: params[:destination_name]
                     ).compact])
      end

      def account_payload(account, params)
        { AccountNumber: account, Amount: params[:amount].amount, TransactionCurrency: params[:amount].currency,
          Narration: params[:narration] || params[:reference] }
      end

      def inquiry_body(params)
        { MessageReference: params[:message_reference] || SecureRandom.uuid, AccountNumber: params[:account_number] }
      end
    end
  end
end
require_relative "coop_bank/auth"
Lipwa::Gateways.register(:coop_bank, Lipwa::Gateways::CoopBank)
