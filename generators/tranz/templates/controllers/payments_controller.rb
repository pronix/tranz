=begin rdoc
Платежи пользователя.
Здесь выводяться транзакции пользователя.
Здесь выполняеться пополнение баланса.

=end
class PaymentsController < ApplicationController
  before_filter :require_user

  def index
    @gateways = Gateway.active
  end

end
