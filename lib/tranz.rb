# Tranz
#
module Tranz
%w{ models controllers views helpers}.each do |dir|
  path = File.join(File.dirname(__FILE__),'app', dir)
  $LOAD_PATH << path
  ActiveSupport::Dependencies.autoload_paths << path
end
end
