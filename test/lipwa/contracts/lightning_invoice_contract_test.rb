# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Contracts
    class LightningInvoiceContractTest < Minitest::Test
      def test_valid_params_pass
        assert contract.call(valid_params).success?
      end

      def test_amount_sats_must_be_a_positive_integer
        [0, -1, "100"].each do |amount|
          refute contract.call(valid_params.merge(amount_sats: amount)).success?
        end
      end

      def test_optional_fields_may_be_nil
        assert contract.call(amount_sats: 100, memo: nil, expiry: nil, webhook_url: nil).success?
      end

      def test_webhook_url_must_be_https
        result = contract.call(valid_params.merge(webhook_url: "http://example.com/invoice"))

        refute result.success?
        assert_includes result.errors.to_h[:webhook_url], "must be an https:// URL"
      end

      private

      def contract
        Lipwa::Contracts::LightningInvoiceContract.new
      end

      def valid_params
        {
          amount_sats: 1_500,
          memo: "Order 123",
          expiry: 900,
          webhook_url: "https://example.com/webhooks/lightning"
        }
      end
    end
  end
end
