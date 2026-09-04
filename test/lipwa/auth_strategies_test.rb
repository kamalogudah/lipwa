# frozen_string_literal: true

require "test_helper"

class AuthStrategiesTest < Minitest::Test
  def test_base_requires_subclasses_to_implement_apply
    assert_raises(NotImplementedError) { Lipwa::AuthStrategies::Base.new.apply(nil) }
  end

  def test_none_does_nothing
    env = new_env
    Lipwa::AuthStrategies::None.new.apply(env)
    assert_empty env.request_headers
  end

  def test_bearer_token_sets_authorization_header_from_callable
    env = new_env
    strategy = Lipwa::AuthStrategies::BearerToken.new(-> { "abc123" })

    strategy.apply(env)

    assert_equal "Bearer abc123", env.request_headers["Authorization"]
  end

  def test_bearer_token_calls_provider_on_every_apply
    calls = 0
    provider = lambda {
      calls += 1
      "token-#{calls}"
    }
    strategy = Lipwa::AuthStrategies::BearerToken.new(provider)

    env1 = new_env
    env2 = new_env
    strategy.apply(env1)
    strategy.apply(env2)

    assert_equal "Bearer token-1", env1.request_headers["Authorization"]
    assert_equal "Bearer token-2", env2.request_headers["Authorization"]
  end

  def test_bearer_token_rejects_non_callable_provider
    assert_raises(ArgumentError) { Lipwa::AuthStrategies::BearerToken.new("static-token") }
  end

  def test_api_key_sets_default_header
    env = new_env

    Lipwa::AuthStrategies::ApiKey.new("secret-key").apply(env)

    assert_equal "secret-key", env.request_headers["X-Api-Key"]
  end

  def test_api_key_sets_custom_header
    env = new_env

    Lipwa::AuthStrategies::ApiKey.new("secret-key", header: "Api-Key").apply(env)

    assert_equal "secret-key", env.request_headers["Api-Key"]
  end

  def test_api_key_rejects_blank_key
    [nil, "", "   "].each do |key|
      assert_raises(ArgumentError) { Lipwa::AuthStrategies::ApiKey.new(key) }
    end
  end

  private

  def new_env
    Faraday::Env.new(request_headers: Faraday::Utils::Headers.new)
  end
end
