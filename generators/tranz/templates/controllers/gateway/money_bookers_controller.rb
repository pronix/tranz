class Gateway::MoneyBookersController < ApplicationController
  before_filter :require_user, :only => [:index, :pay]
  before_filter :allowed_to_use
  layout "refill_balance"

  # Выводим форму в которой пользователь вводит сумму
  def index
  end

  # Получаем сумму которую пользователь хочет перевести
  # и выводим форму платежа
  def pay
    @pay_from_email = params[:pay][:pay_from_email] || ""
    @invoice =  current_user.transactions.new({
             :amount => params[:pay][:amount],
             :gateway =>  @gateway,
             :kind_transaction => Settings.kind_transaction.update_balance,
             :type_payment => Settings.type_payment.foreign,
             :comment => I18n.t('money_bookers.pay_comment'),
             :type_transaction => Settings.type_transaction.credit
            })
    if @invoice.save
      render :action => :pay
    else
      flash[:error] = ["<ul>",@invoice.errors.full_messages.collect{ |x| "<li>#{x}</li>"}, "</ul>"].join
      render :action => :index
    end
  end




#                This is the transaction_id submitted by the
# transaction_id                                                    A205220
#                Merchant
#                This is the MD5 of the following values:
#                -   merchant_id e.g. 123456
#                -   transaction_id e.g. A205220
# msid                                                              730743ed4ef7ec631155f5e15d2f4fa0
#                -   uppercase MD5 value of the ASCII equivalent of
#                    your secret word
#                    e.g. F76538E261E8009140AF89E001341F1

  # возвращаеться ответ что пользователь нажал кнопку оплатить
  def payment_return
    @transaction =  Transaction.open.find_by_id(params[:transaction_id])
    # проверяем что платеж тот что надо
  end


  # отказались от платежа
  def payment_cancel
    @transaction =  Transaction.open.find_by_id(params[:transaction_id])
    @transaction.payment_params = params
    @transaction.comment =  @transaction.comment + I18n.t('money_bookers.flash.canceled_payment')
    @transaction.failure!
    flash[:notice] = I18n.t('money_bookers.flash.canceled_payment')
    redirect_to payment_gateways_url
  end

  # статус платежа по завершение транзакции
  # указываеться оплачен ли счет или нет

  def payment_status

  end

  private
  def allowed_to_use
    @gateway = Gateway.moneybookers
    begin
      flash[:notice] =  I18n.t('gateway_is_not_supported', :default => "Gateway is not supported")
      redirect_to payments_url
    end unless @gateway.payment?
  end

end
