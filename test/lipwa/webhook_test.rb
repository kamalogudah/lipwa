# frozen_string_literal: true

require "test_helper"

class WebhookTest < Minitest::Test
  include Dry::Monads[:result]

  def test_parse_webhook_dispatches_to_the_registered_provider_parser
    key = :"test_wh_#{__method__}"
    parser = ->(body:, **) { Lipwa::WebhookEvent.new(provider: key, event_type: :ping, raw: body) }
    Lipwa::Webhook.register(key, parser)

    result = Lipwa::Webhook.parse_webhook(provider: key, body: { "ok" => true })

    assert result.success?
    event = result.value!
    assert_instance_of Lipwa::WebhookEvent, event
    assert_equal({ "ok" => true }, event.raw)
  end

  def test_parse_webhook_passes_headers_through_to_the_parser
    key = :"test_wh_#{__method__}"
    parser = lambda { |body:, headers:|
      Lipwa::WebhookEvent.new(provider: key, event_type: :ping, raw: body, message: headers["X-Test"])
    }
    Lipwa::Webhook.register(key, parser)

    result = Lipwa::Webhook.parse_webhook(provider: key, body: {}, headers: { "X-Test" => "hi" })

    assert_equal "hi", result.value!.message
  end

  def test_parse_webhook_for_an_unregistered_provider_raises
    error = assert_raises(Lipwa::UnsupportedProviderError) do
      Lipwa::Webhook.parse_webhook(provider: :"test_wh_#{__method__}_unregistered", body: {})
    end
    assert_match(/no webhook parser registered/, error.message)
  end

  def test_parse_webhook_wraps_invalid_json_in_a_failure
    key = :"test_wh_#{__method__}"
    parser = ->(body:, **) { JSON.parse(body) }
    Lipwa::Webhook.register(key, parser)

    result = Lipwa::Webhook.parse_webhook(provider: key, body: "not json")

    assert result.failure?
    assert_instance_of Lipwa::WebhookParseError, result.failure
  end
end

class WebhookEventTest < Minitest::Test
  def test_success_predicate_coerces_nil_to_false
    event = Lipwa::WebhookEvent.new(provider: :test, event_type: :ping, raw: {})

    refute event.success?
  end

  def test_success_predicate_reflects_success_flag
    event = Lipwa::WebhookEvent.new(provider: :test, event_type: :ping, raw: {}, success: true)

    assert event.success?
  end

  def test_verify_signature_delegates_to_the_bound_verifier
    verifier = ->(raw:, token:) { raw == {} && token == "secret" }
    event = Lipwa::WebhookEvent.new(provider: :test, event_type: :ping, raw: {}, verifier: verifier)

    assert event.verify_signature(token: "secret")
    refute event.verify_signature(token: "wrong")
  end

  def test_verify_signature_without_a_bound_verifier_raises
    event = Lipwa::WebhookEvent.new(provider: :test, event_type: :ping, raw: {})

    assert_raises(Lipwa::ConfigurationError) { event.verify_signature }
  end
end
