# frozen_string_literal: true

module Lipwa
  # Base class for everything the gem raises or wraps in a Failure.
  class Error < StandardError; end

  # Raised (not wrapped) when a gateway is misconfigured — missing
  # credentials, invalid environment, etc. A programmer/ops mistake,
  # not something callers should route through Result handling.
  class ConfigurationError < Error; end

  # Raised (not wrapped) when calling a capability method a gateway
  # doesn't include. A programmer mistake caught at call time.
  class UnsupportedCapabilityError < Error; end

  # Raised (not wrapped) when Lipwa::Webhook.parse_webhook is called for
  # a provider with no registered parser. A programmer/config mistake,
  # not something callers should route through Result handling.
  class UnsupportedProviderError < Error; end

  # Wrapped in Failure(...). The inbound webhook body could not be
  # parsed (e.g. invalid JSON) — a runtime condition on untrusted
  # network input, not a programmer mistake.
  class WebhookParseError < Error; end

  # Wrapped in Failure(...). Request params failed contract validation
  # before any network call was made.
  class ValidationError < Error
    attr_reader :validation_result

    def initialize(validation_result)
      @validation_result = validation_result
      super(validation_result.errors.to_h.to_s)
    end
  end

  # Wrapped in Failure(...). The provider's API returned an error, or
  # the HTTP call itself failed (timeout, connection error, etc).
  class GatewayError < Error
    attr_reader :code, :raw

    def initialize(message, code: nil, raw: nil)
      @code = code
      @raw = raw
      super(message)
    end
  end
end
