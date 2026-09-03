# frozen_string_literal: true

require "test_helper"

class CoopBankStatusTestGateway < Lipwa::Gateways::CoopBank
  configure do |config|
    config.base_url = "https://coop-status.example.com"
    config.token_url = "https://coop-status.example.com/token"
    config.api_key = "key"
    config.api_secret = "secret"
  end
end

module Lipwa
  module Gateways
    class CoopBankStatusTest < Minitest::Test
      ENDPOINT = "https://coop-status.example.com/QueryStatus/v1.0.0/query"

      def setup
        stub_request(:post, "https://coop-status.example.com/token")
          .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                     body: { access_token: "token", expires_in: 3600 }.to_json)
      end

      def test_queries_by_message_reference_and_normalizes_response
        stub_request(:post, ENDPOINT)
          .with(body: { MessageReference: "REF-123" }.to_json)
          .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                     body: {
                       MessageReference: "REF-123",
                       MessageCode: 0,
                       MessageDescription: "SUCCESS"
                     }.to_json)

        result = CoopBankStatusTestGateway.new.status(message_reference: "REF-123")

        assert result.success?
        response = result.value!
        assert response.success?
        assert_equal "REF-123", response.provider_reference
        assert_equal "0", response.code
        assert_equal "SUCCESS", response.message
      end
    end
  end
end
