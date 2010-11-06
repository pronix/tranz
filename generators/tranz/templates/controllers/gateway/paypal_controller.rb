require 'activemerchant'
class Gateway::PaypalController < ApplicationController
  include ActiveMerchant::Billing::Integrations
  require 'money'
  layout "refill_balance"

  before_filter :require_user, :only => [:index, :pay]
  before_filter :allowed_to_use
  skip_before_filter :verify_authenticity_token, :only => [:done, :notify]

  def index
  end

  def pay
    @not_panel = true
    @invoice =  current_user.transactions.refill_balance(params[:pay][:amount], @gateway, params[:plan_id])
    unless @invoice.save
      flash[:error] = ["<ul>",
                       @invoice.errors.full_messages.collect{ |x| "<li>#{x}</li>"}, "</ul>"].join
      render :action => :index
    else
      fetch_decrypted(@invoice)
    end

  end

  # PayPal сюда возвращает пользователя после оплаты
  def done
    redirect_to payments_path
  end

  # Уведомление от PayPal о статусе платежа
  def notify
    @notify_paypal = Paypal::Notification.new(request.raw_post)

    if @notify_paypal.acknowledge
      begin
        @transaction =  Transaction.open.find @notify_paypal.invoice
        @transaction.payment_params = params

        if @notify_paypal.complete?
          # Платеж успешно завершен
          @transaction.fee = params[:payment_fee]
          @transaction.comment =  @transaction.comment + ", "+I18n.t('paypal.flash.success_payment')
          @transaction.complete!
          pid = @transaction.comment.split('plan_id ').last.to_i # находим id тарифного плана
          @transaction.user.debit_and_paid(pid) if pid > 0
        else
          # платеж не завершен
          @transaction.comment =  @transaction.comment +", "+ I18n.t('paypal.flash.fail_payment')
          @transaction.failure!
        end

      rescue => e
        # обработка ошибки
      ensure
        # что длеаеться в любом случае
      end
    end
    render :nothing => true
  end

  private
  def allowed_to_use
    @gateway = Gateway.paypal
    begin
      flash[:notice] =  I18n.t('gateway_is_not_supported', :default => "Gateway is not supported")
      redirect_to payments_url
    end unless @gateway.payment?
  end

  def fetch_decrypted(invoice)

    decrypted = {
      "cert_id"       => @gateway.cert_id,
      "cmd"           => @gateway.cmd,
      "business"      => @gateway.business,
      "item_name"     => "#{Settings.site.title.humanize} - #{ Plan.find_by_id(invoice.comment.split('plan_id ').last).name rescue 'пополнение баланса'}",
      "item_number"   => "1",
      "amount"        => invoice.amount,
      "currency_code" => @gateway.currency,
      "country"       => @gateway.country,
      "no_note"       => "1",
      "no_shipping"   => "1",
      "invoice"       => invoice.id,
      "return"        => @gateway.paypal_return

    }
    @encrypted_basic = @gateway.get_encrypted_text decrypted
  end
end
