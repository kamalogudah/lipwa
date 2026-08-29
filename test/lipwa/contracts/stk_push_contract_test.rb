# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Contracts
    class StkPushContractTest < Minitest::Test
      def test_valid_params_pass
        result = contract.call(valid_params)

        assert result.success?
      end

      def test_amount_must_be_a_lipwa_money
        result = contract.call(valid_params.merge(amount: 100))

        refute result.success?
        assert_match(/must be a Lipwa::Money/, result.errors.to_h[:amount].join)
      end

      def test_amount_must_be_kes
        result = contract.call(valid_params.merge(amount: Lipwa::Money.new(amount: 100, currency: "USD")))

        refute result.success?
        assert_includes result.errors.to_h[:amount], "must be KES"
      end

      def test_amount_must_be_greater_than_zero
        result = contract.call(valid_params.merge(amount: Lipwa::Money.new(amount: 0, currency: "KES")))

        refute result.success?
        assert_includes result.errors.to_h[:amount], "must be greater than zero"
      end

      def test_phone_number_must_be_a_valid_msisdn
        result = contract.call(valid_params.merge(phone_number: "0712345678"))

        refute result.success?
        assert_match(/Safaricom MSISDN/, result.errors.to_h[:phone_number].join)
      end

      def test_account_reference_must_be_12_characters_or_fewer
        result = contract.call(valid_params.merge(account_reference: "X" * 13))

        refute result.success?
        assert_includes result.errors.to_h[:account_reference], "must be 12 characters or fewer"
      end

      def test_callback_url_must_be_https
        result = contract.call(valid_params.merge(callback_url: "http://example.com/cb"))

        refute result.success?
        assert_includes result.errors.to_h[:callback_url], "must be an https:// URL"
      end

      def test_transaction_desc_is_optional
        result = contract.call(valid_params.reject { |k, _| k == :transaction_desc })

        assert result.success?
      end

      private

      def contract
        Lipwa::Contracts::StkPushContract.new
      end

      def valid_params
        {
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          phone_number: "254712345678",
          account_reference: "ORDER-123",
          callback_url: "https://example.com/webhooks/mpesa",
          transaction_desc: "Order payment"
        }
      end
    end
  end
end
