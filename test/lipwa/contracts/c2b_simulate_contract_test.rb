# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Contracts
    class C2bSimulateContractTest < Minitest::Test
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

      def test_bill_ref_number_must_be_20_characters_or_fewer
        result = contract.call(valid_params.merge(bill_ref_number: "X" * 21))

        refute result.success?
        assert_includes result.errors.to_h[:bill_ref_number], "must be 20 characters or fewer"
      end

      def test_command_id_must_be_a_known_command
        result = contract.call(valid_params.merge(command_id: "Bogus"))

        refute result.success?
        assert_match(/must be one of/, result.errors.to_h[:command_id].join)
      end

      private

      def contract
        Lipwa::Contracts::C2bSimulateContract.new
      end

      def valid_params
        {
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          phone_number: "254712345678",
          bill_ref_number: "ORDER-123",
          command_id: "CustomerPayBillOnline"
        }
      end
    end
  end
end
