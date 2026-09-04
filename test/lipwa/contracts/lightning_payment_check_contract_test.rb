# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Contracts
    class LightningPaymentCheckContractTest < Minitest::Test
      def test_accepts_a_payment_hash
        assert LightningPaymentCheckContract.new.call(payment_hash: "abc123").success?
      end

      def test_rejects_a_blank_payment_hash
        assert LightningPaymentCheckContract.new.call(payment_hash: "").failure?
      end
    end
  end
end
