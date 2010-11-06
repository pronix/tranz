class CreateGatewaysUsers < ActiveRecord::Migration
  def self.up
  create_table "gateway_users", :force => true do |t|
    t.integer  "user_id",                            :null => false
    t.integer  "gateway_id",                         :null => false
    t.boolean  "default_gateway", :default => false
    t.text     "preferences"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
  add_index :gateway_users, :user_id
  add_index :gateway_users, :gateway_id
  end

  def self.down
    drop_table :gateway_users
  end
end
