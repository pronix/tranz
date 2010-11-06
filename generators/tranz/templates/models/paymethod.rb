=begin rdoc
Типы плат. система
parametrs - параметры для плат. системе(храняться в yaml)
=end
class Paymethod < ActiveRecord::Base
  has_many :transactions
  serialize :parametrs, Hash
  scope :active, :conditions => {:active => true }
  scope :payouts, :conditions => { :payout => true }

  # When we destroy Paymethod we destroy UserPaymethod with name
  after_destroy :clear_user_paymethod
  def clear_user_paymethod
    UserPaymethod.find(:all, :conditions => { :name => self.name }) do |paymethod|
      paymethod.destroy
    end
  end


  class << self

    def webmoney
      find_by_name "WebMoney"
    end

    def money_bookers
      find_by_name "MoneyBookers"
    end

    def paypal
      find_by_name "PayPal"
    end

    def cashu
      find_by_name "Cashu"
    end

  end

end
