class User
  has_many :transactions do
    def refill_balance(summa, gateway, plan_id='')
      build({
        :amount => summa,
        :gateway =>  gateway,
        :kind_transaction => Settings.kind_transaction.update_balance,
        :type_payment => Settings.type_payment.foreign,
        :comment => I18n.t("comment_refill_balance",
                           :default => "Refill balance (#{gateway.name if gateway.respond_to?(:name)})") + "plan_id #{plan_id}",
                           :type_transaction => Settings.type_transaction.credit
      })
    end
  end
end
