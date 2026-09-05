# frozen_string_literal: true

class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.string :kind, null: false            # stk_push | c2b_simulate | disbursement | refund
      t.string :status, null: false, default: "pending" # pending | accepted | rejected | completed | failed
      t.string :provider_reference           # CheckoutRequestID / ConversationID
      t.integer :amount_cents
      t.string :currency
      t.string :phone_number                 # STK push / B2C payee
      t.string :party_b                      # B2B payee shortcode
      t.string :account_reference
      t.text :raw_response
      t.text :error_message

      t.timestamps
    end

    add_index :transactions, :provider_reference
  end
end
