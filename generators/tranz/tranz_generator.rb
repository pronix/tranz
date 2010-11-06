require 'rails/generators'
require 'rails/generators/migration'  

class TranzGenerator < Rails::Generators::Base 

  source_root File.expand_path('../templates', __FILE__) 
  include Rails::Generators::Migration

  def create_initializer_file
    copy_file "lib/public_func.rb", "lib/public_func.rb"
    copy_file "controllers/gateways_controller.rb", "app/controllers/gateways_controller.rb" 
    copy_file "controllers/payments_controller.rb", "app/controllers/payments_controller.rb" 

    empty_directory "app/controllers/gateway"
    copy_file "controllers/gateway/cashu_controller.rb", "app/controllers/gateway/cashu_controller.rb"
    copy_file "controllers/gateway/money_bookers_controller.rb", "app/controllers/gateway/money_bookers_controller.rb"
    copy_file "controllers/gateway/paypal_controller.rb", "app/controllers/gateway/paypal_controller.rb"
    copy_file "controllers/gateway/smsdostup_controller.rb", "app/controllers/gateway/smsdostup_controller.rb"
    copy_file "controllers/gateway/telegate_controller.rb", "app/controllers/gateway/telegate_controller.rb"
    copy_file "controllers/gateway/webmoney_controller.rb", "app/controllers/gateway/webmoney_controller.rb"

    # Models 
    copy_file "models/gateway.rb", "app/models/gateway.rb"
    copy_file "models/paymethod.rb", "app/models/paymethod.rb"
    copy_file "models/settings.rb", "app/models/settings.rb"
    copy_file "models/sms_dostup_tariff.rb", "app/models/sms_dostup_tariff.rb"
    copy_file "models/transaction.rb", "app/models/transaction.rb"
    copy_file "models/user_ext.rb", "app/models/user_ext.rb"

    empty_directory "app/models/gateway"
    copy_file "models/gateway/cashu.rb", "app/models/gateway/cashu.rb"
    copy_file "models/gateway/epassporte.rb", "app/models/gateway/epassporte.rb"
    copy_file "models/gateway/money_bookers.rb", "app/models/gateway/money_bookers.rb"
    copy_file "models/gateway/paypal.rb", "app/models/gateway/paypal.rb"
    copy_file "models/gateway/smsdostup.rb", "app/models/gateway/smsdostup.rb"
    copy_file "models/gateway/telegate.rb", "app/models/gateway/telegate.rb"
    copy_file "models/gateway/webmoney.rb", "app/models/gateway/webmoney.rb"
    directory "views", "app/views", :recursive => true
    copy_file "tasks/gateways.rake", "lib/tasks/gateways.rake"
    directory "db/defaults", "db/defaults"
  end

  def self.next_migration_number(dirname)
    if ActiveRecord::Base.timestamped_migrations
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    else
      "%.3d" % (current_migration_number(dirname) + 1)
    end
  end

  def create_migration_file
    migration_template "db/migrate/create_gateways.rb", "db/migrate/create_gateways.rb"
    sleep 1
    migration_template "db/migrate/create_gateways_users.rb", "db/migrate/create_gateways_users.rb"
    sleep 1
    migration_template "db/migrate/create_paymethods.rb", "db/migrate/create_paymethods.rb"
    sleep 1
    migration_template "db/migrate/create_transactions.rb", "db/migrate/create_transactions.rb"
  end

end
