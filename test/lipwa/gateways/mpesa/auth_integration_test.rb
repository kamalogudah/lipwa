# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Gateways
    class Mpesa
      # Exercises Auth's real HTTP path (no Faraday test stubs) against a
      # sanitized VCR cassette of Daraja's sandbox OAuth response, unlike
      # auth_test.rb which stubs Faraday directly.
      class AuthIntegrationTest < Minitest::Test
        def test_call_fetches_the_access_token_from_the_sandbox_oauth_endpoint
          VCR.use_cassette("mpesa/oauth_success") do
            auth = build_auth

            assert_equal "SANDBOX-TEST-ACCESS-TOKEN", auth.call
          end
        end

        def test_call_reuses_the_cached_token_without_a_second_http_call
          VCR.use_cassette("mpesa/oauth_success") do
            auth = build_auth

            first = auth.call
            second = auth.call

            assert_equal first, second
          end
        end

        private

        def build_auth
          Auth.new(consumer_key: "test-consumer-key", consumer_secret: "test-consumer-secret", env: :sandbox)
        end
      end
    end
  end
end
