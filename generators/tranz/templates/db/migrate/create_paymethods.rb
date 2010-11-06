class CreatePaymethods < ActiveRecord::Migration
  def self.up
  create_table "paymethods", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.string   "login"
    t.string   "password"
    t.text     "signature"
    t.text     "description"
    t.string   "link"
    t.text     "parametrs"
    t.boolean  "active",      :default => false, :null => false
    t.boolean  "payment",     :default => true,  :null => false
    t.boolean  "payout",      :default => false, :null => false
  end
  end

  def self.down
    drop_table :paymethods
  end
end

