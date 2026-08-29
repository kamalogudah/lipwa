# frozen_string_literal: true

require "dry/container"
require "dry/monads"
require "json"
require_relative "errors"

module Lipwa
  # Normalized inbound-webhook event produced by Lipwa::Webhook.parse_webhook.
  # `verify_signature` is bound to a provider-specific verifier at parse
  # time, so callers get one uniform API regardless of how a given
  # provider actually authenticates its callbacks (M-Pesa has no
  # cryptographic signature, so it checks the request's source IP
  # against Safaricom's published ranges; a provider that does sign
  # payloads can verify an HMAC/header instead — see Lipwa::Webhooks::Mpesa).
  class WebhookEvent
    attr_reader :provider, :event_type, :provider_reference, :message, :raw

    # rubocop:disable Metrics/ParameterLists
    def initialize(provider:, event_type:, raw:, success: nil, provider_reference: nil, message: nil, verifier: nil)
      @provider = provider
      @event_type = event_type
      @raw = raw
      @success = success
      @provider_reference = provider_reference
      @message = message
      @verifier = verifier
    end
    # rubocop:enable Metrics/ParameterLists

    def success?
      !!@success
    end

    # kwargs are provider-specific (e.g. `source_ip:` for M-Pesa,
    # `secret:`/`signature_header:` for an HMAC-based provider) — a
    # given verifier only looks at the ones it understands.
    def verify_signature(**opts)
      raise Lipwa::ConfigurationError, "#{provider} has no signature verifier registered" unless @verifier

      @verifier.call(raw: raw, **opts)
    end
  end

  # Inbound-callback parsing/verification, pluggable per provider.
  # Providers register a parser once (typically at load time — see
  # Lipwa::Webhooks::Mpesa); consumers call Lipwa::Webhook.parse_webhook
  # instead of hand-rolling per-provider payload parsing in their
  # controllers.
  module Webhook
    extend Dry::Container::Mixin
    extend Dry::Monads[:result]

    class << self
      def register(provider, parser)
        super(provider.to_sym, parser)
      end

      def parse_webhook(provider:, body:, headers: {})
        Success(resolve(provider.to_sym).call(body: body, headers: headers))
      rescue Dry::Container::KeyError
        raise Lipwa::UnsupportedProviderError, "no webhook parser registered for #{provider.inspect}"
      rescue JSON::ParserError => e
        Failure(Lipwa::WebhookParseError.new(e.message))
      end
    end
  end
end
