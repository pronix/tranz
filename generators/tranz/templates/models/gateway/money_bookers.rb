class Gateway::MoneyBookers < Gateway
  preference :link, :default => '/gateway/money_bookers'#, :access_level => :protected
  preference :url, :default => "https://www.moneybookers.com/app/payment.pl"#,
                   #:access_level => :protected
  preference :pay_to_email       # Аккаунт сервиса
  preference :recipient_description
  preference :return_url_text, :default => "return to back site"
  preference :return_url_target, :default => 3
  preference :cancel_url_target, :default => 3
  preference :language, :default => "EN"
  preference :currency, :default => "USD"
  preference :pay_from_email#, :access_level => :user  # Аккаунт пользователя

  def provider_class
    self.class
  end
end
