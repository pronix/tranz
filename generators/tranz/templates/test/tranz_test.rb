require File.dirname(__FILE__) + '/test_helper'
class TranzTest < Test::Unit::TestCase
  load_schema
  class Transaction < ActiveRecord::Base ; end
  class Gateway < ActiveRecord::Base ; end
  def test_schema_has_loaded_correctly
    assert_equal [], Transaction.all
    assert_equal [], Gateway.all
  end
end
