# frozen_string_literal: true

class Transaction < ApplicationRecord
  KINDS = %w[stk_push c2b_simulate disbursement refund].freeze

  validates :kind, inclusion: { in: KINDS }
end
