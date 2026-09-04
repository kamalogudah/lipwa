# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Contracts
    class LightningInvoiceCheckContractTest < Minitest::Test
      def test_payment_hash_is_required
        result = contract.call(payment_hash: "")

        refute result.success?
        assert result.errors.to_h.key?(:payment_hash)
      end

      def test_payment_hash_must_be_a_string
        refute contract.call(payment_hash: 123).success?
      end

      def test_valid_payment_hash_passes
        assert contract.call(payment_hash: "payment-hash-123").success?
      end

      private

      def contract
        Lipwa::Contracts::LightningInvoiceCheckContract.new
      end
    end
  end
end
