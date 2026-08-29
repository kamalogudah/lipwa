# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_29_000002) do
  create_table "transactions", force: :cascade do |t|
    t.string "account_reference"
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.string "currency"
    t.text "error_message"
    t.string "kind", null: false
    t.string "party_b"
    t.string "phone_number"
    t.string "provider_reference"
    t.text "raw_response"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_reference"], name: "index_transactions_on_provider_reference"
  end

  create_table "webhook_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.text "payload", null: false
    t.string "provider_reference"
    t.boolean "success"
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["provider_reference"], name: "index_webhook_events_on_provider_reference"
  end
end
