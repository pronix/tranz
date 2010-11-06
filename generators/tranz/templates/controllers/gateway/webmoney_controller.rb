require "digest/md5"
class Gateway::WebmoneyController < ApplicationController
  before_filter :require_user, :only => [:index]
  layout "refill_balance"
  skip_before_filter :verify_authenticity_token, :only => :payment

  before_filter :allowed_to_use
  before_filter :parse_payment_params, :only => [:payment_result, :payment_success, :payment_fail]
  before_filter :valid_payment, :only => [:payment_result]

  # Выводим форму с текущим балансом пользователя и с полем для суммы пополнения
  def index
  end

  # Получаем от пользователя сумму которую он хочет перечислить на баланс
  # Создаем открытую. внешнию транзакцию
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


  # Результат платежа
  # Получаем данные об оплате, проверяем их,
  # записываем данные платежа в транзакцию и закрываем оплаченную транзакцию
  def payment_result
    @transaction =  Transaction.open.find @payment_params[:payment_no]
    @transaction.payment_params = @payment_params
    if @transaction.complete!
      pid = @transaction.comment.split('plan_id ').last.to_i # находим id тарифного плана
      @transaction.user.debit_and_paid(pid) if pid > 0
      render :text => "Success"
    else
      render :text => "No"
    end
  end

  # Подтвержение успешной оплаты
  # Проверяем что нужная транзакция уже закрыта и проведена
  def payment_success
    # FIXME при запросе на саксес в вебмани не передается ни каких параметров - т.к. они ранее переданы на payment_result
    # потому делаю что б всегда успешно обрабатывалось
    begin
    @transaction =  Transaction.success.find @payment_params[:payment_no]
    @transaction.payment_params = @payment_params
    if @transaction.success?
      flash[:notice] = I18n.t('webmoney.flash.success_payment', :default => "Success")
      redirect_to payments_url
    else
      # TODO
      # Здесь можно сделать отправку сообщения что платеж не зачислен
      @transaction.comment =  @transaction.comment + I18n.t('webmoney.warning')
      render :text => I18n.t('webmoney.flash.fail_payment', :default => "Fail")
    end
    rescue
      flash[:notice] = I18n.t('webmoney.flash.success_payment', :default => "Success")
      redirect_to payments_url
    end
  end

  # Платеж отменен
  # закрываем транзакцию со статусом error (не удачное завершение транзакции)
  def payment_fail
    @transaction =  Transaction.open.find @payment_params[:payment_no]
    @transaction.payment_params = @payment_params
    @transaction.comment =  [@transaction.comment,
                             I18n.t('webmoney.flash.canceled_payment', :default => "Cancel")
                            ].join(" ")
    @transaction.cancel!
    flash[:notice] = I18n.t('webmoney.flash.canceled_payment', :default => "Cancel")
    redirect_to payments_url
  end


  private

  def allowed_to_use
    @gateway = Gateway.webmoney
    begin
      flash[:notice] =  I18n.t('gateway_is_not_supported',
                               :default => "Gateway is not supported")

      redirect_to payments_url
    end unless @gateway.payment?
  end

  # разбираем параметры
  def parse_payment_params
    @payment_params = HashWithIndifferentAccess.new
     params.each do |key, value|
      if key.starts_with?('LMI_')
        @payment_params[key.gsub(/^LMI_/, "").downcase] = value
      end
    end
  end

  # Проверяем верен ли платеж
  def valid_payment
    if @payment_params[:prerequest] == "1" # предварительный запрос
        render :text => "YES"
    elsif  @gateway.secret.blank?  # если не указан секретный ключ
      render :text => "WebMoney secret key is not provided"
    elsif ! @payment_params[:hash] ==  # если мд5 не совпает
        Digest::MD5.hexdigest([
                               @payment_params[:payee_purse],    @payment_params[:payment_amount],
                               @payment_params[:payment_no],     @payment_params[:mode],
                               @payment_params[:sys_invs_no],    @payment_params[:sys_trans_no],
                               @payment_params[:sys_trans_date], @gateway.secret,
                               @payment_params[:payer_purse],    @payment_params[:payer_wm]
                              ].join("")).upcase

      render :text => "not valid payment"
    end

  end

end

