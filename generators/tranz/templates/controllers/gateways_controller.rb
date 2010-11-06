=begin rdoc
Редактирование ИД плат. шлюза пользователем
=end
class GatewaysController < ApplicationController
  before_filter :require_user

  def edit
    @gateway_user = current_user.gateway_users.find_by_gateway_id params[:id]
    @gateway_user ||= current_user.gateway_users.build :gateway_id => params[:id]
    @gateway = @gateway_user.gateway
    render :layout => false
  end
end
