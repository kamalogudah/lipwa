# frozen_string_literal: true

require "base64"
require "openssl"
require_relative "base"

module Lipwa
  module AuthStrategies
    # Adds Jenga HQ's OAuth2 bearer token and RSA-SHA256 request signature.
    #
    # Jenga defines a different signature formula for each endpoint. The
    # signature_payload callable receives the Faraday::Env for the outgoing
    # request and must return the exact concatenated String required by that
    # endpoint (without separators). It is evaluated for every request.
    class Jenga < Base
      def initialize(token_provider:, private_key:, signature_payload:)
        super()
        validate_callable!(token_provider, :token_provider)
        validate_callable!(signature_payload, :signature_payload)

        @token_provider = token_provider
        @private_key = parse_private_key(private_key)
        @signature_payload = signature_payload
      end

      def initialize_copy(source)
        super
        @token_provider = @token_provider.dup
      end

      def apply(env)
        payload = @signature_payload.call(env)
        raise ArgumentError, "signature_payload must return a String" unless payload.is_a?(String)

        signature = @private_key.sign(OpenSSL::Digest.new("SHA256"), payload)
        env.request_headers["Authorization"] = "Bearer #{@token_provider.call}"
        env.request_headers["Signature"] = Base64.strict_encode64(signature)
      end

      private

      def validate_callable!(value, name)
        raise ArgumentError, "#{name} must respond to #call" unless value.respond_to?(:call)
      end

      def parse_private_key(private_key)
        key = private_key.is_a?(OpenSSL::PKey::RSA) ? private_key : OpenSSL::PKey::RSA.new(private_key)
        raise ArgumentError, "private_key must contain an RSA private key" unless key.private?

        key
      rescue OpenSSL::PKey::PKeyError, TypeError
        raise ArgumentError, "private_key must be an RSA private key or PEM encoded RSA private key"
      end
    end

    JengaHQ = Jenga
  end
end
