class CreateTransactions < ActiveRecord::Migration
  def self.up
  create_table "transactions", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "amount"
    t.float    "fee"
    t.string   "status"
    t.string   "comment"
    t.integer  "paymethod_id"
    t.integer  "user_id"
    t.integer  "kind_transaction"
    t.integer  "type_payment"
    t.integer  "type_transaction"
    t.text     "payment_params"
    t.float    "finite_sum"
    t.integer  "gateway_id"
  end
    add_index :transactions,:user_id
    add_index :transactions, :paymethod_id
    add_index :transactions, :gateway_id
  end

  def self.down
    drop_table :transactions
  end
end

