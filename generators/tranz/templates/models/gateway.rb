class Gateway < ActiveRecord::Base
  serialize :preferences, Hash
  cattr_reader :providers

  @provider = nil?
  @@providers = [ Gateway::Webmoney, Gateway::Paypal, Gateway::Cashu, Gateway::MoneyBookers, Gateway::Epassporte, Gateway::Telegate, Gateway::Smsdostup ]

  validates_presence_of :name, :type
  validates_uniqueness_of :type
  validates_inclusion_of  :type, :in => @@providers.map(&:to_s)
  validates_numericality_of :max_amount, :min_amount, :allow_nil => true

  validate :fee_valid
  # Комисcия по платежной системе
  def fee_valid
    raw_value = self.fee.to_s.strip[/%$/] ? self.fee.to_s.strip[0..-2] : self.fee.to_s.strip
    raw_value = Kernel.Float(raw_value)
  rescue  ArgumentError, TypeError
    errors.add("fee", :not_a_number, :value => raw_value)
  end

  def display_fee
    fee_in_percentage? ? fee.to_s[0..-2] : fee.to_s
  end

  def fee_to_float
    Kernel.Float((fee_in_percentage? ? fee.to_s[1..-2] : fee.to_s))
  end

  def fee_in_percentage?
    fee.to_s[/%$/] ? true : false
  end

  def flat_fee?
    fee.to_s[/%$/] ? false : true
  end


  %w(active payment payout).each do |m|
    scope m.to_sym, :conditions => { m.to_sym => true }
  end

  class << self
    # Переопределяем что будет сохраняться в type,
    def sti_name
      "Gateway::#{super}"
    end

    @@providers.map(&:to_s).each do |m|
      define_method m.demodulize.downcase  do |*args|
        first :conditions => { :type => "Gateway::#{m.demodulize}" }
      end
    end

  end # end class << self

  def gateway_type
    new_record? ? self.class.to_s :
      read_attribute("type")
  end
  def gateway_type=(v)
    write_attribute("type",v)
  end


  def provider_class
    raise "You must implement provider_class method for this gateway."
  end

  def provider
    ActiveMerchant::Billing::Base.gateway_mode = server.to_sym
    gateway_options = options
    gateway_options[:test] = true if test_mode
		@provider ||= provider_class.new(gateway_options)
  end

  def method_missing(method, *args)
	 	if @provider.nil?
			super
		else
			@provider.respond_to?(method) ? provider.send(method) : super
		end
	end

  def sms_gateway?
    self.class.const_defined?(:SMS_GATEWAY) && self.class.const_get(:SMS_GATEWAY)
  end
end
