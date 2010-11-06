require "digest/md5"
class Gateway::CashuController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => :success
  before_filter :require_user, :only => [:index, :pay]
  before_filter :allowed_to_use
  before_filter :valid_payment, :only => [:success]  # проверка параметров ответа от cashU

  def index
  end

  def pay
    @invoice =  current_user.transactions.refill_balance(params[:pay][:amount], @gateway, params[:plan_id])
    if @invoice.save
      @token = @gateway.token(@invoice.amount)
      render :action => :pay
    else
      flash[:error] = ["<ul>",@invoice.errors.full_messages.collect{ |x| "<li>#{x}</li>"}, "</ul>"].join
      render :action => :index
    end
  end

  # При оплате пользователем платежа система cushU возвращает успешный результат.
  # При отрицательном платеже система cashU ничего не возвращает.
  def success
    @transaction = Transaction.open.find params[:session_id]
    @transaction.payment_params = params
    if @transaction.complete!
      pid = @transaction.comment.split('plan_id ').last.to_i # находим id тарифного плана
      @transaction.user.debit_and_paid(pid) if pid > 0
      flash[:notice] = 'Successfully'
      render :text => "Success"
    else
      flash[:notice] = 'Not payment'
      render :text => "No"
    end
  end


  private
  def allowed_to_use
    @gateway = Gateway.cashu
    begin
      flash[:notice] =  I18n.t('gateway_is_not_supported', :default => "Gateway is not supported")
      redirect_to payments_url
    end unless @gateway.payment?
  end

  def valid_payment
    unless @gateway.valid_token?(params[:token], params[:amount], params[:currency])
      render :text => "not valid payment"
    end
  end

end
