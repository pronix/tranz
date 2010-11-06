# -*- coding: utf-8 -*-

script_dir = File.dirname(__FILE__)
source_dir = File.join(script_dir, 'lib', 'app')
dest_dir   = File.join(RAILS_ROOT, 'app')

def files_in_path(path)
  Dir.glob(File.join path, '*')
end

# Добавить гемы от которых зависит плагин в Gemfile приложения

gems_required = File.new(File.join(script_dir, 'Gemfile')).read
File.new(File.join(RAILS_ROOT, "Gemfile"), "a") << "\n#{gems_required}\n"

# Копируем генераторы

dest_gen_dir = FileUtils.mkdir_p File.join(RAILS_ROOT, "lib", "generators")

files_in_path([script_dir, "generators"]).each do |generator|
  FileUtils.cp_r generator, dest_gen_dir
end
