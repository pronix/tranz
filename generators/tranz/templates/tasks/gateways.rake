# encoding: utf-8
require 'active_record/fixtures'
namespace :db do
  namespace :tranz do
    namespace :sample_data do
      desc "Load sample data from db/defaults"
      task :load_sample_data => :environment do
        ActiveRecord::Base.establish_connection(Rails.env.to_sym)
        Gateway.destroy_all

        Dir.glob(File.join(Rails.root.to_s, "db", 'defaults', '*.{yml,csv}')).each do |fixture_file|
          puts fixture_file
          Fixtures.create_fixtures("#{Rails.root.to_s}/db/defaults",
                                   File.basename(fixture_file, '.*'))
        end
      end
    end
  end
end
