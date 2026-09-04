# frozen_string_literal: true

require "base64"
require "openssl"
require_relative "../webhook"

module Lipwa
  module Webhooks
    # Parses Jenga HQ receive-payment Instant Payment Notifications (IPNs).
    module Jenga
      module_function

      # rubocop:disable Metrics/MethodLength
      def call(body:, headers: {})
        payload = parse(body)
        transaction = payload.fetch("transaction", {})
        authorization = header(headers, "Authorization")

        Lipwa::WebhookEvent.new(
          provider: :jenga,
          event_type: :receive_payment,
          success: transaction["status"].to_s.casecmp?("SUCCESS"),
          provider_reference: transaction["reference"],
          message: transaction["remarks"],
          raw: payload,
          verifier: lambda do |raw:, username:, password:, **|
            verify_signature(raw: raw, authorization: authorization, username: username, password: password)
          end
        )
      end
      # rubocop:enable Metrics/MethodLength

      def parse(body)
        body.is_a?(String) ? JSON.parse(body) : body
      end

      def verify_signature(raw:, authorization:, username:, password:) # rubocop:disable Lint/UnusedMethodArgument
        return false unless authorization && username && password

        expected = "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
        return false unless authorization.bytesize == expected.bytesize

        OpenSSL.fixed_length_secure_compare(authorization, expected)
      end

      def header(headers, name)
        pair = headers.find { |key, _| key.to_s.casecmp?(name) }
        pair&.last
      end
    end
  end
end

Lipwa::Webhook.register(:jenga, Lipwa::Webhooks::Jenga)
