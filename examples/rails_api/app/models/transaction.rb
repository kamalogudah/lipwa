# frozen_string_literal: true

class Transaction < ApplicationRecord
  KINDS = %w[stk_push c2b_simulate disbursement refund jenga_transfer jenga_disbursement].freeze

  validates :kind, inclusion: { in: KINDS }
end
