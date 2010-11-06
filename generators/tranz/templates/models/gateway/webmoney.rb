class Gateway::Webmoney < Gateway

  preference :secret
  preference :wmid
  preference :payee_purse
  preference :cert, :default => File.join(Rails.root.to_s,"cert/webmoney/webmoney.cer"),
  :access_level => :protected
  preference :link, :default => '/gateway/webmoney', :access_level => :protected
  preference :purse_dest, :access_level => :user
  preference :url,  :default => 'https://merchant.webmoney.ru/lmi/payment.asp',
                    :access_level => :protected

  # TODO отключаем валидацию параметров плат. систем так как пока не будет автоматического перевода денег
  # validates_presence_of :secret, :wmid, :payee_purse, :unless => lambda{ |t| t.new_record? }
  # validates_format_of   :payee_purse,  :with => /^[R|Z][0-9]{12}/, :unless => lambda{ |t| t.new_record? }



  def provider_class
    self.class
  end

  # Проверка пользовательского ид при составление заявки на вывод денег
  # Если есть ошибки то записываем из в _errors (ActiveRecord::Errors)
  def valid_user_params _purse_dest, _errors
    if _purse_dest.blank?
      _errors.add_on_blank("purse_dest")
    end

    unless _purse_dest.to_s =~ /^[R|Z][0-9]{12}/
      _errors.add("purse_dest", :invalid,
                  :value => _purse_dest)
    end
  end


  # ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  # webmoney transfer
  # ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  def wm(gw = self)
    @wm ||= Class.new do
      include ::Webmoney
      def initialize(_gw)
        @ssl_cert = OpenSSL::X509::Certificate.new File.read(_gw.cert)
        super(:wmid => _gw.wmid, :cert => @ssl_cert )
      end
    end.new(gw)
    @wm
  end


  def bussines_level
    wm.request(:bussines_level, :wmid => self.wmid)
  end

  def balance
    wm.request(:balance, :wmid => @wmid)
  rescue => ex
    raise  Iconv.new('UTF-8', 'WINDOWS-1251').iconv(ex.message)
  end

  # Вывод денег вебмастером
  def transfer claim
    wm.request(:create_transaction, :wmid => self.wmid,
               :transid =>   claim.id,                   # номер заявки
               :pursesrc =>  self.payee_purse,
               :pursedest => claim.purse_dest,           # кошелек пользователя
               :amount =>    claim.finite_sum.to_f)          # сумма

  end


  # Массовые выплаты
  # Возвращаем xml и парметры файла
  def masspay(claims, description = "MediaVialise (webmoney) : masspay.")
    @accept_claims = []
    @error_claims  = []

    @xml = Nokogiri::XML::Builder.new {  |x|
      x.payments(:xmlns => "http://tempuri.org/ds.xsd") {
        claims.each do |cl|

          @u = cl.user
          if @u.claim_on_payouts.summa_claim <= @u.earned_money.to_f
            # по заявке хватает денег, создаем транзакцию и формируем часть xml

            @accept_claims << cl
            x.payment{
              x.destination  cl.purse_dest
              x.amount       cl.finite_sum
              x.description  PayoutPattern.match(description, cl).to_s

              x.id_ cl.id
            }

          else
            # по этой заявке нехватает денег
            @error_claims << cl
          end

        end

      }

    }

    return @xml.to_xml,
    { :type => 'text/xml; charset=utf-8; header=present',
      :filename => "masspay_webmoney_#{Time.now.strftime("%d_%m_%Y")}.xml" }


  end

end
