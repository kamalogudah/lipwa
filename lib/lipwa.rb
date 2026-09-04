# frozen_string_literal: true

require_relative "lipwa/version"
require_relative "lipwa/errors"
require_relative "lipwa/types"
require_relative "lipwa/money"
require_relative "lipwa/response"
require_relative "lipwa/auth_strategies"
require_relative "lipwa/http_adapter"
require_relative "lipwa/configuration"
require_relative "lipwa/capability"
require_relative "lipwa/gateway"
require_relative "lipwa/gateways"
require_relative "lipwa/webhook"
require_relative "lipwa/webhooks/mpesa"
require_relative "lipwa/contracts/c2b_register_urls_contract"
require_relative "lipwa/contracts/c2b_simulate_contract"
require_relative "lipwa/capabilities/c2b"
require_relative "lipwa/contracts/stk_push_contract"
require_relative "lipwa/capabilities/stk_push"
require_relative "lipwa/contracts/disbursement_contract"
require_relative "lipwa/capabilities/disbursement"
require_relative "lipwa/contracts/status_query_contract"
require_relative "lipwa/capabilities/status_query"
require_relative "lipwa/contracts/bank_transfer_contract"
require_relative "lipwa/capabilities/bank_transfer"
require_relative "lipwa/gateways/mpesa"
require_relative "lipwa/gateways/coop_bank"

require_relative "lipwa/gateways/jenga"
# Unified payment gateway abstraction for African payment providers.
module Lipwa
  def self.gateway(name)
    Gateways[name]
  end
end
