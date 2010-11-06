class CreateGateways < ActiveRecord::Migration
  def self.up
  create_table "gateways", :force => true do |t|
    t.string   "type"
    t.string   "name"
    t.text     "description"
    t.boolean  "active",       :default => false
    t.boolean  "payment",      :default => true
    t.boolean  "payout",       :default => false
    t.boolean  "test_mode",    :default => false
    t.string   "fee"
    t.float    "max_amount"
    t.float    "min_amount"
    t.boolean  "masspay_flag", :default => false
    t.text     "preferences"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
  end

  def self.down
    drop_table :gateways
  end
end
