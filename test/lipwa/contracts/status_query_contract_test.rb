# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Contracts
    class StatusQueryContractTest < Minitest::Test
      def test_valid_params_pass
        result = contract.call(valid_params)

        assert result.success?
      end

      def test_transaction_id_is_required
        result = contract.call(valid_params.merge(transaction_id: ""))

        refute result.success?
        assert result.errors.to_h.key?(:transaction_id)
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

      def test_coop_message_reference_shape_passes
        result = contract.call(message_reference: "8f618d57-14e2-4e56-91f8-649ca920318b")

        assert result.success?
      end

      def test_a_provider_reference_is_required
        result = contract.call({})

        refute result.success?
        assert result.errors.to_h.key?(:transaction_id)
      end

      def test_transaction_id_and_message_reference_are_mutually_exclusive
        result = contract.call(valid_params.merge(message_reference: "REF-1"))

        refute result.success?
        assert result.errors.to_h.key?(:message_reference)
      end

      private

      def contract
        Lipwa::Contracts::StatusQueryContract.new
      end

      def valid_params
        {
          transaction_id: "OEI2AK4Q16",
          remarks: "Confirming payment",
          result_url: "https://example.com/webhooks/mpesa/result",
          queue_timeout_url: "https://example.com/webhooks/mpesa/timeout",
          occasion: nil
        }
      end
    end
  end
end
