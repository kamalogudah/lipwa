# frozen_string_literal: true

require "dry/validation"

module Lipwa
  module Contracts
    # Validates the kwargs Lipwa::Capabilities::StatusQuery#status is
    # called with, before any network call is made. PartyA and
    # IdentifierType aren't part of the schema — like Disbursement's
    # PartyA, they're always the gateway's own shortcode, not a
    # per-call param.
    class StatusQueryContract < Dry::Validation::Contract
      schema do
        optional(:transaction_id).maybe(:string)
        optional(:message_reference).maybe(:string)
        optional(:remarks).maybe(:string)
        optional(:result_url).maybe(:string)
        optional(:queue_timeout_url).maybe(:string)
        optional(:occasion).maybe(:string)
      end

      rule(:transaction_id, :message_reference) do
        if values[:transaction_id].to_s.empty? && values[:message_reference].to_s.empty?
          key(:transaction_id).failure("or message_reference must be filled")
        elsif values[:transaction_id] && values[:message_reference]
          key(:message_reference).failure("cannot be used with transaction_id")
        end
      end

      rule(:remarks, :transaction_id) do
        key(:remarks).failure("must be filled") if values[:transaction_id] && values[:remarks].to_s.empty?
      end

      rule(:result_url, :transaction_id) do
        key(:result_url).failure("must be filled") if values[:transaction_id] && values[:result_url].to_s.empty?
      end

      rule(:queue_timeout_url, :transaction_id) do
        if values[:transaction_id] && values[:queue_timeout_url].to_s.empty?
          key(:queue_timeout_url).failure("must be filled")
        end
      end

      rule(:result_url) do
        key.failure("must be an https:// URL") if value && !value.start_with?("https://")
      end

      rule(:queue_timeout_url) do
        key.failure("must be an https:// URL") if value && !value.start_with?("https://")
      end
    end
  end
end
