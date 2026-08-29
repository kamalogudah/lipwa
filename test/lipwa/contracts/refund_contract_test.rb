# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Contracts
    class RefundContractTest < Minitest::Test
      def test_valid_params_pass
        result = contract.call(valid_params)

        assert result.success?
      end

      def test_transaction_id_is_required
        result = contract.call(valid_params.merge(transaction_id: ""))

        refute result.success?
        assert result.errors.to_h.key?(:transaction_id)
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

      def test_remarks_is_required
        result = contract.call(valid_params.merge(remarks: ""))

        refute result.success?
        assert result.errors.to_h.key?(:remarks)
      end

      def test_result_url_must_be_https
        result = contract.call(valid_params.merge(result_url: "http://example.com/result"))

        refute result.success?
        assert_includes result.errors.to_h[:result_url], "must be an https:// URL"
      end

      def test_queue_timeout_url_must_be_https
        result = contract.call(valid_params.merge(queue_timeout_url: "http://example.com/timeout"))

        refute result.success?
        assert_includes result.errors.to_h[:queue_timeout_url], "must be an https:// URL"
      end

      def test_occasion_is_optional
        result = contract.call(valid_params.merge(occasion: nil))

        assert result.success?
      end

      private

      def contract
        Lipwa::Contracts::RefundContract.new
      end

      def valid_params
        {
          transaction_id: "OEI2AK4Q16",
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          remarks: "Missing item",
          result_url: "https://example.com/webhooks/mpesa/result",
          queue_timeout_url: "https://example.com/webhooks/mpesa/timeout",
          occasion: nil
        }
      end
    end
  end
end
