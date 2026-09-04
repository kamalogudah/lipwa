# frozen_string_literal: true

require "test_helper"

class JengaAuthTest < Minitest::Test
  TOKEN_URL = "https://jenga.example.com/authenticate"

  def test_fetches_and_caches_merchant_token
    clock = -> { Time.utc(2026, 9, 4, 9, 0, 0) }
    request = stub_request(:post, TOKEN_URL)
              .with(
                headers: { "Api-Key" => "api-key", "Content-Type" => "application/json" },
                body: { merchantCode: "merchant-1", consumerSecret: "secret" }.to_json
              )
              .to_return(
                status: 200,
                headers: { "Content-Type" => "application/json" },
                body: {
                  accessToken: "access-token",
                  expiresIn: "2026-09-04T09:15:00Z"
                }.to_json
              )
    auth = build_auth(clock: clock)

    assert_equal "access-token", auth.call
    assert_equal "access-token", auth.call
    assert_requested request, times: 1
  end

  def test_wraps_unsuccessful_oauth_response
    stub_request(:post, TOKEN_URL)
      .to_return(status: 401, body: { message: "invalid credentials" }.to_json)

    error = assert_raises(Lipwa::GatewayError) { build_auth.call }

    assert_equal "401", error.code
    assert_equal({ "message" => "invalid credentials" }, error.raw)
  end

  def test_requires_all_credentials
    assert_raises(Lipwa::ConfigurationError) do
      Lipwa::Gateways::Jenga::Auth.new(
        api_key: nil,
        merchant_code: "merchant",
        consumer_secret: "secret",
        token_url: TOKEN_URL
      )
    end
  end

  private

  def build_auth(clock: -> { Time.utc(2026, 9, 4, 9, 0, 0) })
    Lipwa::Gateways::Jenga::Auth.new(
      api_key: "api-key",
      merchant_code: "merchant-1",
      consumer_secret: "secret",
      token_url: TOKEN_URL,
      clock: clock
    )
  end
end
