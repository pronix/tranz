ActiveRecord::Schema.define(:version => 0) do
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
