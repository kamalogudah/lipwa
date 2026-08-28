# frozen_string_literal: true

require "faraday"
require "dry/configurable"

module Lipwa
  extend Dry::Configurable

  setting :logger
  setting :default_timeout, default: 10
  setting :adapter, default: Faraday.default_adapter
end
