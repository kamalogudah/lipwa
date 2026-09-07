# frozen_string_literal: true

require "faraday"
require "json"

module Lipwa
  module Logging
    REDACTED = "[REDACTED]"

    # Produces sanitized copies of nested payloads without mutating caller data.
    module Redactor
      SECRET_NAMES = "authorization|signature|cookie|api[_-]?key|access[_-]?token|" \
                     "refresh[_-]?token|token|consumer[_-]?key|client[_-]?id|" \
                     "secret|password|passkey|" \
                     "security[_-]?credential|private[_-]?key|admin[_-]?key|invoice[_-]?key|encryption[_-]?key"
      SENSITIVE_KEY = /(?:#{SECRET_NAMES})/i
      STRING_PATTERNS = [
        /((?:authorization|proxy-authorization|signature)\s*:\s*)[^\r\n,]+/i,
        /((?:^|[?&])(?:#{SECRET_NAMES})=)[^&#\s]+/i,
        /(["']?(?:#{SECRET_NAMES})["']?\s*[:=]\s*["'])[^"']*(["'])/i
      ].freeze

      module_function

      def call(value, key: nil) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
        return REDACTED if sensitive_key?(key)

        case value
        when Hash
          value.each_with_object({}) do |(child_key, child_value), copy|
            copy[child_key] = call(child_value, key: child_key)
          end
        when Array then value.map { |item| call(item) }
        when String then redact_string(value)
        when Exception then { class: value.class.name, message: redact_string(value.message) }
        else value
        end
      end

      def sensitive_key?(key) = key&.to_s&.match?(SENSITIVE_KEY)

      def redact_string(value)
        STRING_PATTERNS.reduce(value.dup) do |redacted, pattern|
          redacted.gsub(pattern) { "#{Regexp.last_match(1)}#{REDACTED}#{Regexp.last_match(2)}" }
        end
      end
    end

    # Faraday middleware that emits one structured, sanitized event per call.
    class Middleware < Faraday::Middleware
      def initialize(app, logger)
        super(app)
        @logger = logger
      end

      def call(env)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @app.call(env).on_complete { |completed| log(completed, started_at) }
      rescue StandardError => e
        log(env, started_at, error: e)
        raise
      end

      private

      def log(env, started_at, error: nil) # rubocop:disable Metrics/AbcSize
        event = {
          event: "lipwa.http", method: env.method&.to_s&.upcase,
          url: sanitized_url(env.url), status: env.status,
          duration_ms: elapsed_ms(started_at),
          request: { headers: Redactor.call(env.request_headers.to_h), body: redact_body(env.request_body) },
          response: { headers: Redactor.call(env.response_headers.to_h), body: redact_body(env.response_body) }
        }
        event[:error] = Redactor.call(error) if error
        @logger.public_send(error || env.status.to_i >= 400 ? :error : :info, event)
      end

      def sanitized_url(url)
        return unless url

        copy = url.dup
        copy.user = REDACTED if copy.user
        copy.password = REDACTED if copy.password
        copy.query = Redactor.redact_string(copy.query) if copy.query
        copy.to_s
      end

      def redact_body(body)
        parsed = body.is_a?(String) ? JSON.parse(body) : body
        Redactor.call(parsed)
      rescue JSON::ParserError
        Redactor.call(body)
      end

      def elapsed_ms(started_at)
        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)
      end
    end
  end
end
