# Платежный шлюз Smsdostup
# http://smsdostup.ru/index.php
class Gateway::Smsdostup < Gateway
  SMS_GATEWAY = true

  preference :project_id # ид проекта
  preference :keyword    # Ключевое слово
  preference :md5_code   # MD5 код:
  preference :tariff_url,  :default => 'http://www.smsdostup.ru/billing-tarifs.xml' # урл для получения тарифово
  preference :link, :default => '/gateway/smsdostup'#, :access_level => :protected

  def provider_class
    self.class
  end

  def sms_text(plan,user)
    str = "#{self.keyword}--#{plan.name}--#{plan.id}--#{plan.price}--#{self.md5_code}--#{Settings.sms_salt}--#{user.persistence_token}"
    Rails.logger.debug { "hashed sms textt: '#{str}'" }
    Digest::MD5.hexdigest(str)[0..5].upcase
  end

end
