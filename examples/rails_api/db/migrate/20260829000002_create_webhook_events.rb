# frozen_string_literal: true

class CreateWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_events do |t|
      t.string :event_type, null: false      # stk_callback | c2b
      t.string :provider_reference
      t.boolean :verified, null: false, default: false
      t.boolean :success
      t.text :payload, null: false

      t.timestamps
    end

    add_index :webhook_events, :provider_reference
  end
end
