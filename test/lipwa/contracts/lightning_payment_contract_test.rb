# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Contracts
    class LightningPaymentContractTest < Minitest::Test
      def test_accepts_a_bolt11_invoice
        assert LightningPaymentContract.new.call(bolt11: "lnbc15u1example").success?
      end

      def test_rejects_a_blank_invoice
        assert LightningPaymentContract.new.call(bolt11: "").failure?
      end
    end
  end
end
