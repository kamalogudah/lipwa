# frozen_string_literal: true

require "dry/struct"
require_relative "types"

module Lipwa
  # Normalized result of a successful gateway call. Provider-specific
  # payloads stay available via `raw` for anything the common shape
  # doesn't capture.
  class Response < Dry::Struct
    attribute :success, Types::Strict::Bool
    attribute :provider_reference, Types::Strict::String.optional
    attribute :message, Types::Strict::String.optional.default(nil)
    attribute :code, Types::Strict::String.optional.default(nil)
    attribute :raw, Types::Any.default(nil)

    def success?
      success
    end
  end
end
