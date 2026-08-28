# frozen_string_literal: true

require_relative "base"

module Lipwa
  module AuthStrategies
    # Default strategy: adds nothing. Used for endpoints that need no
    # auth (e.g. some public sandbox calls) or as a placeholder while a
    # gateway is configured.
    class None < Base
      def apply(env); end
    end
  end
end
