class Gateway::TelegateController < ApplicationController
  before_filter :require_user, :only => [:index, :pay]
  layout "refill_balance"
  skip_before_filter :verify_authenticity_token, :only => [:status, :ok, :fail, :info]

  before_filter :allowed_to_use
  before_filter :parse_payment_params, :only => [:status, :ok, :fail, :info]

  def index
  end

  def pay
    @not_panel = true
    @invoice =  current_user.transactions.refill_balance(params[:pay][:amount], @gateway, params[:plan_id])
    if @invoice.save
      render :action => :pay
    else
      flash[:notice] = ["<ul>",
                       @invoice.errors.full_messages.collect{ |x| "<li>#{x}</li>"}, "</ul>"].join
      render :action => :index
    end

  end

  # Обработка платежей
  # URL, на который будет перенаправлен покупатель в случае успешной оплаты.
  # Подтвержение успешной оплаты
  # Проверяем что нужная транзакция уже закрыта и проведена
  def ok
    begin
      @transaction =  Transaction.success.find @payment_params[:inv_id]
      if @transaction.success?
        flash[:notice] = I18n.t('telegate.flash.success_payment', :default => "Success")
        redirect_to payments_url
      else
        @transaction.comment =  @transaction.comment + I18n.t('telegate.warning')
        render :text => I18n.t('telegate.flash.fail_payment', :default => "Fail")
      end
    rescue
      flash[:notice] = I18n.t('telegate.flash.fail_payment', :default => "fail")
      redirect_to payments_url
    end
  end

  # URL, на который будет перенаправлен покупатель в случае выбора не мгновенного способа оплаты.
  # Эту страницу покупатель может посетить после выписки счета. На ней вы можете разместить дополнительную информацию для ваших покупателей.
  def info
    flash[:notice] = I18n.t('telegate.flash.info', :default => "info")
    redirect_to payments_url
  end

  # URL, на который будет перенаправлен покупатель в случае НЕ успешной покупки. В настоящий момент автоматизированные платежи не поддерживаются.
  def fail
    @transaction =  Transaction.open.find @payment_params[:inv_id]
    @transaction.payment_params = @payment_params
    @transaction.comment =  [@transaction.comment,
                             I18n.t('telegate.flash.canceled_payment', :default => "Cancel")
                            ].join(" ")
    @transaction.cancel!
    flash[:notice] = I18n.t('telegate.flash.canceled_payment', :default => "Cancel")
    redirect_to payments_url
  end

  # URL, на который система будет посылать запрос при каждом успешном платеже, или же e-mail адрес, если в качестве метода выбран E-mail.
  # Если в этом поле ничего не указано, то уведомление отсутствует.
  def status
    if valid_payment?(@payment_params) # подпись совпадает
      @transaction =  Transaction.open.find @payment_params[:inv_id]
      @transaction.payment_params = @payment_params
      if @transaction.complete!
        pid = @transaction.comment.split('plan_id ').last.to_i # находим id тарифного плана
        @transaction.user.debit_and_paid(pid) if pid > 0
        render :text => "OK"
      else
        render :nothing => true
      end
    else
      render :nothing => true
    end
  end



  private

  # SYS_TRANS_ID	ID заказа в системе Telegate	3452
  # AMOUNT	Сумма заказа в валюте сайта	250
  # CURRENCY	Валюта сайта	USD
  # DATE_INT	Дата и время оплаты заказа в виде unix timestamp	1210259314
  # PAY_METHOD	Способ оплаты	WMZ
  # USER_FIRST_NAME	Имя плательщика	Иван
  # USER_SECOND_NAME	Фамилия плательщика	Иванов
  # USER_LAST_NAME	Отчество плательщика	Иванович
  # USER_COUNTRY	Страна плательщика	Россия
  # USER_CITY	Город плательщика	Москва
  # USER_ZIP	Почтовый код плательщика	195000
  # USER_ADDRESS	Адрес плательщика	ул. Ленина дом 1
  # USER_PHONE	Телефон плательщика	+74951234567
  # USER_EMAIL	E-mail плательщика	customer@mail.com
  # USER_IP	IP плательщика	127.0.0.1
  # HASH	Цифровая подпись запроса. Используется для проверки данных пришедших в запросе.
  # Подробнее описано в разделе Формирование подписи	d41d8cd98f00b204e9800998ecf8427e
  # INV_ID	ID заказа в системе магазина	1244
  # Пример для проверки
  # HTTParty.get("http://localhost:3000/gateway/telegate/status",
  #          :body => { :sys_trans_id => 3452, :amount => 2.99, :currency => 'usd', :date_int => Time.now.to_i, :pay_method => 'wmz',
  #                     :user_first_name => 'Иван', :user_second_name => 'Иванов', :user_last_name => 'Иванович',
  #                     :user_country => 'Россия', :user_city => 'Москва', :user_zip => 195000, :user_address => 'ул. Ленина дом 1', :user_phone => '+74951234567',
  #                     :user_email => 'customer@mail.com', :user_ip => '127.0.0.1', :hash => Digest::MD5.hexdigest([3452, 196, 2.99,'usd', 'wmz', "onebaks123"].join),
  #                     :inv_id => '196'
  #                      })

  def parse_payment_params
    @params_key = ['sys_trans_id', 'amount', 'currency', 'date_int', 'pay_method', 'user_first_name',	'user_second_name',
                   'user_last_name', 'user_country', 'user_city', 'user_zip', 'user_address', 'user_phone', 'user_email',
                   'user_ip', 'hash', 'inv_id' ] # параметры которые возвращает telegate
    @payment_params = HashWithIndifferentAccess.new
    params.each do |key, value|
      if @params_key.include?(key.downcase)
        @payment_params[key.downcase] = value
      end
    end

  end

  # Проверяем валидность платежа
  def valid_payment?(payment_params)
    # .Формирование подписи.
    # Подпись запроса формируется следующим образом:
    # Параметры передаваемые на STATUS_URL конкатенируются в следующей последовательности:
    # SYS_TRANS_ID+ INV_ID+AMOUNT+CURRENCY+ PAY_METHOD+WEBSITE_SECRET_WORD, где WEBSITE_SECRET_WORD — секретное слово, установленное в настройках сайта.
    # От полученной строки берется md5. Результирующая строка будет являться цифровой подписью.
    Digest::MD5.hexdigest([
                           payment_params[:sys_trans_id], payment_params[:inv_id], payment_params[:amount],
                           payment_params[:currency], payment_params[:pay_method], @gateway.secret
                          ].join) == payment_params[:hash]
  end

  # Проверяем что шлюз TeleGate доступен
  def allowed_to_use
    @gateway = Gateway.telegate
    begin
      flash[:notice] =  I18n.t('gateway_is_not_supported', :default => "Gateway is not supported")
      redirect_to payments_url
    end unless @gateway.payment?
  end

end
