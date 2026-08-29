# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Gateways
    class Mpesa
      class AuthTest < Minitest::Test
        def test_uses_sandbox_base_url_by_default
          auth = build_auth(env: :sandbox)

          assert_equal "https://sandbox.safaricom.co.ke", auth.instance_variable_get(:@http).base_url
        end

        def test_uses_production_base_url_when_configured
          auth = build_auth(env: :production)

          assert_equal "https://api.safaricom.co.ke", auth.instance_variable_get(:@http).base_url
        end

        def test_unknown_env_raises_configuration_error
          assert_raises(Lipwa::ConfigurationError) do
            Auth.new(consumer_key: "key", consumer_secret: "secret", env: :staging)
          end
        end

        def test_missing_credentials_raises_configuration_error
          assert_raises(Lipwa::ConfigurationError) do
            Auth.new(consumer_key: nil, consumer_secret: "secret")
          end
        end

        def test_call_fetches_and_returns_the_access_token
          requests = 0
          stubs = Faraday::Adapter::Test::Stubs.new do |stub|
            stub.get("/oauth/v1/generate") do |env|
              requests += 1
              assert_equal "Basic a2V5OnNlY3JldA==", env.request_headers["Authorization"]
              assert_equal "client_credentials", env.params["grant_type"]
              [200, { "Content-Type" => "application/json" }, '{"access_token":"abc123","expires_in":"3599"}']
            end
          end

          auth = build_auth(stubs: stubs)

          assert_equal "abc123", auth.call
          assert_equal 1, requests
        end

        def test_call_caches_the_token_until_it_is_close_to_expiring
          requests = 0
          stubs = Faraday::Adapter::Test::Stubs.new do |stub|
            stub.get("/oauth/v1/generate") do
              requests += 1
              [200, { "Content-Type" => "application/json" }, '{"access_token":"abc123","expires_in":"3599"}']
            end
          end
          now = Time.now
          auth = build_auth(stubs: stubs, clock: -> { now })

          auth.call
          auth.call

          assert_equal 1, requests
        end

        def test_call_refreshes_once_the_cached_token_is_within_the_expiry_buffer
          requests = 0
          stubs = Faraday::Adapter::Test::Stubs.new do |stub|
            stub.get("/oauth/v1/generate") do
              requests += 1
              [200, { "Content-Type" => "application/json" }, '{"access_token":"abc123","expires_in":"120"}']
            end
          end
          now = Time.now
          clock = -> { now }
          auth = build_auth(stubs: stubs, clock: clock)

          auth.call
          now += 61 # inside the 60s buffer of a 120s-lived token
          auth.call

          assert_equal 2, requests
        end

        def test_call_raises_gateway_error_on_unexpected_response_shape
          stubs = Faraday::Adapter::Test::Stubs.new do |stub|
            stub.get("/oauth/v1/generate") { [200, { "Content-Type" => "application/json" }, "{}"] }
          end
          auth = build_auth(stubs: stubs)

          assert_raises(Lipwa::GatewayError) { auth.call }
        end

        private

        def build_auth(consumer_key: "key", consumer_secret: "secret", env: :sandbox, stubs: nil,
                       clock: -> { Time.now })
          http = stubs && Lipwa::HttpAdapter.new(base_url: Auth::BASE_URLS.fetch(env), stubs: stubs)
          Auth.new(
            consumer_key: consumer_key,
            consumer_secret: consumer_secret,
            env: env,
            http: http,
            clock: clock
          )
        end
      end
    end
  end
end
