# frozen_string_literal: true

require_relative "lipwa/version"
require_relative "lipwa/errors"
require_relative "lipwa/types"
require_relative "lipwa/money"
require_relative "lipwa/response"
require_relative "lipwa/auth_strategies"
require_relative "lipwa/http_adapter"
require_relative "lipwa/capability"
require_relative "lipwa/gateway"
require_relative "lipwa/gateways"

# Unified payment gateway abstraction for African payment providers.
module Lipwa
  def self.gateway(name)
    Gateways[name]
  end
end
