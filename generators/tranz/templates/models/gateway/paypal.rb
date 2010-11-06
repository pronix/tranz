class Gateway::Paypal < Gateway

  preference :cert_id  # ИД Сертификата
  preference :cmd, :default => "_xclick"
  preference :business # аккаунт сервису - куда переводить деньги
  preference :currency, :default => "USD"
  preference :country, :default => "EN"
  preference :url, :default =>
    (ENV['RAILS_ENV'] == "production" ?
     "https://www.paypal.com/uk/cgi-bin/webscr" :
     "https://www.sandbox.paypal.com/uk/cgi-bin/webscr")#, :access_level => :protected
  preference :link, :default => "/gateway/paypal"#, :access_level => :protected

  preference :login # логин для paypal api
  preference :password # пароль для paypal api
  preference :signature # сигнатура для paypal api

  preference :purse_dest#, :access_level => :user # Кошелек пользователя

  preference :paypal_return,
             :default => "http://[?]/gateway/paypal/done"

  preference :cert_file,
             :default => File.join(Rails.root.to_s, "cert/paypal/my-pubcert.pem")#,
             #:access_level => :protected

  preference :key_file,
             :default => File.join(Rails.root.to_s, "cert/paypal/my-prvkey.pem")#,
             #:access_level => :protected

  preference :paypal_cert_file,
             :default => File.join(Rails.root.to_s, "cert/paypal/paypal_cert.pem" )#,
             #:access_level => :protected



  # validates_presence_of :cert_id, :business,
  #                       :if => lambda{ |t| t.active? && t.payment? && !t.new_record? }

  # validates_presence_of :link, :login, :password, :signature,
  #                       :if => lambda{ |t| t.active? && t.payout? && !t.new_record? }

  def provider_class
    self.class
  end

  # Шифруем текст
  def get_encrypted_text(hs)
    IO.popen("/usr/bin/openssl smime -sign -signer #{self.cert_file} -inkey #{self.key_file} -outform der -nodetach -binary | /usr/bin/openssl smime -encrypt -des3 -binary -outform pem #{self.paypal_cert_file}", 'r+') do |pipe|
      hs.each { |x,y| pipe << "#{x}=#{y}\n" }
      pipe.close_write
      @data = pipe.read
    end
    @data
  end

  # Проверка пользовательского ид при составление заявки на вывод денег
  # Если есть ошибки то записываем из в _errors (ActiveRecord::Errors)
  def valid_user_params _purse_dest, _errors
    if _purse_dest.blank?
      errors.add_on_blank("purse_dest")
    end

    unless _purse_dest.to_s =~ /\A[A-Z0-9_\.%\+\-]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,4})\z/i
      _errors.add("purse_dest", :invalid,
                  :value => _purse_dest)
    end
  end


  # Вывод денег вебмастером
  def transfer claim
    @gateway = ActiveMerchant::Billing::PaypalGateway.new({
                   :login => self.login, :password =>self.password,
                   :pem => nil,  :signature => self.signature })
    @response = @gateway.transfer(claim.finite_sum, claim.purse_dest,
                                   :subject => "Payouts from  Mediavalise", :note => "")

    @result =  {
      :params     => @response.params,
      :avs_result => @response.avs_result,
      :message    => @response.message
    }

    if @response.success?
      @result
    else
      raise "[ paypal ] transfer error : #{@response.message }"
    end
  end

  # Массовые выплаты
  def masspay(claims, description = "MediaVialise (paypal) : masspay.")
    @accept_claims = []
    @error_claims  = []
    @text = FasterCSV.generate({ :col_sep => "\t", :encoding => "UTF-8"}) do |csv|
      claims.each do |cl|
        @u = cl.user
        if @u.claim_on_payouts.summa_claim <= @u.earned_money.to_f
          # по заявке хватает денег, создаем транзакцию и формируем часть xml
          @accept_claims << cl
          csv << [cl.purse_dest, cl.finite_sum.to_s, PayoutPattern.match(description, cl).to_s, cl.id.to_s]
        else
          # по этой заявке нехватает денег
          @error_claims << cl
        end

      end
    end

    return @text,
    { :type => 'text/csv; charset=utf-8; header=present',
      :filename => "masspay_paypal_#{Time.now.strftime("%d_%m_%Y")}.csv" }
  end
end
