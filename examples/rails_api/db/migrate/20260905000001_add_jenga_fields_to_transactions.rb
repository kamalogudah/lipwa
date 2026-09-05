# frozen_string_literal: true

class AddJengaFieldsToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :rail, :string unless column_exists?(:transactions, :rail)
    add_column :transactions, :source_account, :string unless column_exists?(:transactions, :source_account)
    add_column :transactions, :destination_account, :string unless column_exists?(:transactions, :destination_account)
  end
end
