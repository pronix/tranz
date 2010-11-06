# Платежный шлюз TeleGate
class Gateway::Telegate < Gateway

  preference :secret # секретное слово
  preference :ws_id  # ид сайта
  preference :url,  :default => 'https://www.telegate.ru/secure/order.php'#, # урл telegate
                    #:access_level => :protected
  preference :pay_method  # метод оплаты
  # Желаемый способ оплаты. Если параметр задан, то пользователю будет доступен на выбор только этот способ оплаты. Примите во внимание, что установка этого параметра не гарантирует то, что пользователь будет использовать именно указанный способ оплаты. Возможные варианты этого параметра даны в разделе Коды методов платежей
  preference :link, :default => '/gateway/telegate'#, :access_level => :protected

  def provider_class
    self.class
  end



  # ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  # telegate transfer
  # ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


  # # Вывод денег вебмастером
  # def transfer claim
  # end


  # # Массовые выплаты
  # # Возвращаем xml и парметры файла
  # def masspay(claims, description = "MediaVialise (telegate) : masspay.")
  # end

end
