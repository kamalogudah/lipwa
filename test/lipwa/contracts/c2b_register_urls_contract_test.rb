# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Contracts
    class C2bRegisterUrlsContractTest < Minitest::Test
      def test_valid_params_pass
        result = contract.call(valid_params)

        assert result.success?
      end

      def test_validation_url_must_be_https
        result = contract.call(valid_params.merge(validation_url: "http://example.com/validate"))

        refute result.success?
        assert_includes result.errors.to_h[:validation_url], "must be an https:// URL"
      end

      def test_confirmation_url_must_be_https
        result = contract.call(valid_params.merge(confirmation_url: "http://example.com/confirm"))

        refute result.success?
        assert_includes result.errors.to_h[:confirmation_url], "must be an https:// URL"
      end

      def test_response_type_must_be_completed_or_cancelled
        result = contract.call(valid_params.merge(response_type: "Bogus"))

        refute result.success?
        assert_match(/must be one of/, result.errors.to_h[:response_type].join)
      end

      private

      def contract
        Lipwa::Contracts::C2bRegisterUrlsContract.new
      end

      def valid_params
        {
          validation_url: "https://example.com/webhooks/mpesa/validate",
          confirmation_url: "https://example.com/webhooks/mpesa/confirm",
          response_type: "Completed"
        }
      end
    end
  end
end
