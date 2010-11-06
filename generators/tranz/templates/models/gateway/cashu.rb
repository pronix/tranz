class Gateway::Cashu < Gateway

  preference :link, :default => '/gateway/cashu'#, :access_level => :protected
  preference :url, :default => 'https://www.cashu.com/cgi-bin/pcashu.cgi'#, :access_level => :protected
  preference :language, :default => "en"
  preference :currency, :default => "USD"
  preference :merchant_id # ид продовца в cashU
  preference :encryption_word # секретное слово

  # validates_presence_of :merchant_id, :encryption_word

  def provider_class
    self.class
  end
  def token(amount)
    Digest::MD5.hexdigest([
                           self.merchant_id,
                           amount.to_s,
                           self.currency,
                           self.encryption_word].map(&:downcase).join(':'))

  end
  def valid_token?(token, amount, currency)
    token == Digest::MD5.hexdigest([
                                    self.merchant_id,
                                    amount,currency,
                                    self.encryption_word
                                   ].map(&:downcase).join(":"))

  end
end
