# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Contracts
    class DisbursementContractTest < Minitest::Test
      def test_valid_b2c_params_pass
        result = contract.call(valid_b2c_params)

        assert result.success?
      end

      def test_valid_b2b_params_pass
        result = contract.call(valid_b2b_params)

        assert result.success?
      end

      def test_amount_must_be_a_lipwa_money
        result = contract.call(valid_b2c_params.merge(amount: 100))

        refute result.success?
        assert_match(/must be a Lipwa::Money/, result.errors.to_h[:amount].join)
      end

      def test_amount_must_be_kes
        result = contract.call(valid_b2c_params.merge(amount: Lipwa::Money.new(amount: 100, currency: "USD")))

        refute result.success?
        assert_includes result.errors.to_h[:amount], "must be KES"
      end

      def test_amount_must_be_greater_than_zero
        result = contract.call(valid_b2c_params.merge(amount: Lipwa::Money.new(amount: 0, currency: "KES")))

        refute result.success?
        assert_includes result.errors.to_h[:amount], "must be greater than zero"
      end

      def test_command_id_must_be_known
        result = contract.call(valid_b2c_params.merge(command_id: "Bogus"))

        refute result.success?
        assert_match(/must be one of/, result.errors.to_h[:command_id].join)
      end

      def test_party_b_must_be_a_valid_msisdn_for_b2c_command_ids
        result = contract.call(valid_b2c_params.merge(party_b: "0712345678"))

        refute result.success?
        assert_match(/Safaricom MSISDN/, result.errors.to_h[:party_b].join)
      end

      def test_party_b_is_not_msisdn_validated_for_b2b_command_ids
        result = contract.call(valid_b2b_params.merge(party_b: "600000"))

        assert result.success?
      end

      def test_account_reference_is_required_for_b2b_command_ids
        result = contract.call(valid_b2b_params.merge(account_reference: nil))

        refute result.success?
        assert_includes result.errors.to_h[:account_reference], "is required for B2B command IDs"
      end

      def test_account_reference_is_not_required_for_b2c_command_ids
        result = contract.call(valid_b2c_params.merge(account_reference: nil))

        assert result.success?
      end

      def test_result_url_must_be_https
        result = contract.call(valid_b2c_params.merge(result_url: "http://example.com/result"))

        refute result.success?
        assert_includes result.errors.to_h[:result_url], "must be an https:// URL"
      end

      def test_queue_timeout_url_must_be_https
        result = contract.call(valid_b2c_params.merge(queue_timeout_url: "http://example.com/timeout"))

        refute result.success?
        assert_includes result.errors.to_h[:queue_timeout_url], "must be an https:// URL"
      end

      private

      def contract
        Lipwa::Contracts::DisbursementContract.new
      end

      def valid_b2c_params
        {
          command_id: "SalaryPayment",
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          party_b: "254712345678",
          remarks: "August salary",
          result_url: "https://example.com/webhooks/mpesa/result",
          queue_timeout_url: "https://example.com/webhooks/mpesa/timeout",
          occasion: nil,
          account_reference: nil
        }
      end

      def valid_b2b_params
        {
          command_id: "BusinessPayBill",
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          party_b: "600000",
          remarks: "Settlement",
          result_url: "https://example.com/webhooks/mpesa/result",
          queue_timeout_url: "https://example.com/webhooks/mpesa/timeout",
          occasion: nil,
          account_reference: "INV-123"
        }
      end
    end
  end
end
