class Gateway::Epassporte < Gateway
  preference :purse_dest#, :access_level => :user

  def provider_class
    self.class
  end



  # Проверка пользовательского ид при составление заявки на вывод денег
  # Если есть ошибки то записываем из в _errors (ActiveRecord::Errors)
  def valid_user_params _purse_dest, _errors
    if _purse_dest.blank?
      errors.add_on_blank("purse_dest")
    end

    unless _purse_dest.to_s =~ /\w+/
      _errors.add("purse_dest", :invalid, :value => _purse_dest)
    end
    unless _purse_dest.to_s.length >= 5
      _errors.add("purse_dest", :too_short, :value => _purse_dest, :count => 5)
    end
    unless _purse_dest.to_s.length <= 12
      _errors.add("purse_dest", :too_long, :value => _purse_dest, :count => 12)
    end
  end

  def masspay(claims, description = "MediaVialise (epassporte) : masspay.")
    @accept_claims = []
    @error_claims  = []
    @text =  FasterCSV.generate({ :col_sep => "|", :encoding => "UTF-8"}) do |csv|
      claims.each do |cl|
        @u = cl.user
        if @u.claim_on_payouts.summa_claim <= @u.earned_money.to_f
          # по заявке хватает денег, создаем транзакцию и формируем часть xml
          @accept_claims << cl
          csv << [cl.purse_dest, cl.finite_sum.to_s, PayoutPattern.match(description, cl).to_s]
        else
          # по этой заявке нехватает денег
          @error_claims << cl
        end

      end
    end

    return @text,
    { :type => 'text/csv; charset=utf-8; header=present',
      :filename => "masspay_epassporte_#{Time.now.strftime("%d_%m_%Y")}.csv" }
  end

end
