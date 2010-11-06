=begin rdoc
Транзакции

=end
include PublicFunc
class Transaction < ActiveRecord::Base

  include AASM

  belongs_to :user
  belongs_to :paymethod
  belongs_to :gateway

  validates_presence_of :gateway_id, :if => lambda{ |t|
                                                t.type_payment == Settings.type_payment.foreign }

  validates_presence_of :user_id, :type_payment, :amount, :type_transaction, :kind_transaction
  validates_numericality_of :amount, :on => :create

  validate :can_buy, :if => lambda{ |t| t.debit? }

  def can_buy
    errors.add_to_base("Недостаточно денег") unless self.amount <= user.earned_money
  end

  after_create :calculate_fee
  def calculate_fee
    self.finite_sum = self.fee.blank? ? self.amount : (self.amount - self.fee)
    #save_with_validation(false)
  end

  serialize :payment_params, Hash

  aasm_column :status
  aasm_initial_state lambda{ |t| t.type_payment == Settings.type_payment.internal ? :internal : :open  }

  aasm_state :internal
  aasm_state :open
  aasm_state :success, :enter => :change_balance, :exit => :refund
  aasm_state :error
  aasm_state :canceled

  aasm_event :complete do
    transitions :to => :success, :from => :open
  end

  # ошибка
  aasm_event :failure do
    transitions :to => :error, :from => :open
  end

  # отмена
  aasm_event :cancel do
    transitions :to => :canceled, :from => :open
  end

  # делаем откат , возвращаем списанные деньги пользователю
  aasm_event :rollback do
    transitions :to => :error, :from => :success
  end

  # возвращает транзакции по покупкам paid аккаунтов
  scope :purchases_paid, lambda{ |user_ids| {
      :conditions => ["user_id in (?) and kind_transaction = ? and created_at > ?",
                      user_ids,Settings.kind_transaction.purchase_paid,
                      (Time.now - Settings.rating.n_days.to_i.days).to_s(:db) ]
    }}

  scope :cashouts, lambda{ {
    :conditions => { :kind_transaction => Settings.kind_transaction.cashouts}
    }}

  scope :debits, :conditions => { :type_transaction => Settings.type_transaction.debit }
  scope :credits, :conditions => { :type_transaction => Settings.type_transaction.credit }


  def debit?
    self.type_transaction == Settings.type_transaction.debit
  end

  def credit?
    self.type_transaction == Settings.type_transaction.credit
  end

  # При завершение внешней транзакции, делаем начиление или списание по пользователю
  def change_balance
    unless self.internal? # только внешнии транзакции
      if self.debit?  # списание
        user.transaction do
          user.earned_money = user.earned_money.to_f - self.amount
          user.save
        end
      elsif self.credit? # пополнение
        user.transaction do
          user.earned_money = user.earned_money.to_f + self.amount
          user.save
        end
      end
    end
  end

  # возвращаем даньги на баланс пользователя
  def refund
    unless self.internal? # только внешнии транзакции
      if self.debit?  # списание
        user.transaction do
          user.earned_money = user.earned_money.to_f + self.amount
          user.save
        end
      elsif self.credit? # пополнение
        user.transaction do
          user.earned_money = user.earned_money.to_f - self.amount
          user.save
        end
      end
    end
  end

  class << self

    def plans_to_admin_dashboard(from_date=20.year.ago)
      tmp = { }
      all_amount = 0
      Plan.all.each do |plan|
        one_plan = find(:all,
                        :conditions => ['kind_transaction = ? AND type_payment = ? AND comment LIKE ? AND created_at >= ?',
                                        Settings.kind_transaction.purchase_paid,
                                        Settings.type_transaction.debit,
                                        "Buy paid account: #{plan.name}",
                                        from_date])
        tmp.merge!({ plan.name => [one_plan.size, sum_field_model(one_plan, 'finite_sum')]})
        all_amount += sum_field_model(one_plan, 'finite_sum')
      end
      return tmp, all_amount
    end

  end

end

