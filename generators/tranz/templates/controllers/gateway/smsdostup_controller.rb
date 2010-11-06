# Оплата услуги через смс биллинг SmsDostup
# smsdostup.ru/
class Gateway::SmsdostupController < ApplicationController
  # layout "refill_balance"
  before_filter :require_user, :only => [:index, :operators, :tarrif, :pay]
  skip_before_filter :verify_authenticity_token, :only => :result
  before_filter :parse_payment_params, :only => :result
  after_filter :this_xml_needs_to_be_in_cp1251, :only => :result
  # Определяем текущую страну пользователя и выводим список стран
  # и список операторов
  # при выборе оператора выводим что нужно послать смс на нужные номера
  def index
    @plan = Plan.find params[:plan_id]
    db = GeoIPCity::Database.new(GEOIP_DATA)
    @location = db.look_up request.ip

    @countries = SmsDostupCountry.all
    !@location.blank? &&
      @current_country =  SmsDostupCountry.find_by_code(@location[:country_code].downcase, :include => [:sms_dostup_operators])
    @current_country ||= SmsDostupCountry.find_by_code("ru", :include => [:sms_dostup_operators])

    @operators = @current_country.try(:sms_dostup_operators)

  end

  # По стране выбираем оператров
  def operators
    @country = SmsDostupCountry.find_by_id(params[:id], :include => [:sms_dostup_operators])
    @operators = @country.sms_dostup_operators
    respond_to do |format|
      format.html { }
      format.js   { render :action =>  :operators, :layout => false }
      format.json { render :json => @operators.to_json}
    end
  end

  # Для Оператора выбираем способ оплаты
  def tarrif
    @plan = Plan.find params[:plan_id]
    @operator = SmsDostupOperator.find_by_id(params[:id])
    session[:operator_id] = @operator.id
    @gateway = Gateway.smsdostup
    @sms_text = @gateway.sms_text(@plan, current_user)
    @tarrif = @operator.get_tarrif(@plan)
    respond_to do |format|
      format.html{ }
      format.js { render :action => :tarrif, :layout => false }
    end
  end

  # Принятие кода от пользователя и включение оплаты
  def pay

    @plan = Plan.find params[:plan_id]
    @gateway = Gateway.smsdostup
    @operator = SmsDostupOperator.find_by_id(params[:operator_id])

    # Эти данные нужны чтоб выводить ошибку на той же страницы где и вводился код
    @sms_text = @gateway.sms_text(@plan, current_user)
    @tarrif = @operator.get_tarrif(@plan)
    @countries = SmsDostupCountry.all
    @current_country = @operator.sms_dostup_country
    @operators = @current_country.try(:sms_dostup_operators)

    # Находим по коду, что отправили пользователю, платеж через смс, и проверяем чтоб платеж уже не был
    @sms_payment = SmsPayment.sent.find_by_code(params[:sms_code])


    if !@sms_payment.blank? && (@sms_payment.user_code == @gateway.sms_text(@plan, current_user))  # платеж по смс обнаружен
      @invoice =  current_user.transactions.refill_balance(@plan.price, @gateway, @plan.id)
      @invoice.payment_params = @sms_payment.payment_params
      @invoice.save
      if @invoice.complete! # платеж завершен
        @invoice.user.debit_and_paid(@plan.id) # включение тарифного плана
        @sms_payment.complete!
        flash[:notice] = I18n.t('sms_dostup.flash.success_payment', :default => "Success")
        redirect_to payments_url
      else
        flash[:error] = "Платеж найден, но тариф не подключен, обратитесь с службу тех . поддержки. Номер Вашего платежа #{@invoice.id}"
        render :index
      end
    else # платеж по смс не обнаружен
      if @sms_payment.blank?
        flash[:error] = "Платеж не найден."
      else
        flash[:error] = "Платеж найден, но тариф не соответствует платежу, обратитесь с службу тех . поддержки. Номер Вашего платежа #{@invoice.id}"
      end
      render :index
    end

  end

  # Обработка ответа от SmsDostup
  def result
    @gateway = Gateway.smsdostup
    if @payment_params[:is_debug] # тестовый платеж
      render :text => "<SMSDOSTUP>OK</SMSDOSTUP>", :status => :ok
    else
      if Digest::MD5.hexdigest([@gateway.md5_code,              @payment_params[:session_code], # проверка ключа
                                @payment_params[:sms_id],       @payment_params[:sms_number],
                                @payment_params[:sms_operator], @payment_params[:sms_phone],
                                @payment_params[:sms_message],  @payment_params[:sms_price]].join) == @payment_params[:md5_hash]
        @project_id, @user_code = @payment_params[:sms_message].split # парсим текст смс на префикс и код который прислал пользователь

        # Если смс еще не приходила
        unless SmsPayment.find_by_sms_id_and_spec_id(@payment_params[:sms_id], @payment_params[:spec_id])
          @sms_payment = SmsPayment.create({ # Записываем что пришла смс
                                             :user_code => @user_code, :gateway_id => @gateway.id, :prefix => @project_id,
                                             :payment_params => @payment_params,
                                             :sms_id => @payment_params[:sms_id], :spec_id => @payment_params[:spec_id],
                                             :amount => @payment_params[:sms_price]
                                           })
           @sms_payment.generate_code if @sms_payment.code.blank? # генерируем код для пользователя если в автомате не сгенерировался
          # Даем ответ смс dostup
          render :text => "<SMSDOSTUP>Mediavalise, Vash kod: #{@sms_payment.code}</SMSDOSTUP>.", :status => :ok
        else
          # смс уже приходила, выдаем ответ OK
          render :text => "<SMSDOSTUP>OK</SMSDOSTUP>", :status => :ok
        end

      else
        # подпись не совпала, выдаем NO
        render :text => "<SMSDOSTUP>NO</SMSDOSTUP>", :status => :ok
      end

    end
  end

  private

  # Парсим параметры от smsdistup
  # Теперь можно приступать к проверке пришедших параметров. Список передаваемых Вашему скрипту параметров содержит следующие элементы:
  # _is_debug = 1 (параметр тестирования проекта, по-умолчанию не передается)
  # _md5_hash = a123456789b123456789c123456789d1 (ключ проверки целостности данных)
  # _session_code = 9194ac153d8421a161b7ef17ga80a1f3 (ключ текущей сессии)
  # _sms_id =1234567890 (уникальный идентификатор смс сообщения) **
  # _sms_number = 1234 (короткий номер, на который прислано смс сообщение)
  # _sms_operator = Megafon (название оператора, латиница, короткое)
  # _sms_operator_full = Megafon_moscow (название оператора, латиница, полное)
  # _sms_phone = 7912xxxx345 (номер абонента, приславшего смс сообщение)
  # _sms_country = ru (страна абонента, приславшего смс сообщение)
  # _sms_message = ttpogoda (полный текст сообщения)
  # _sms_plain = dHRzbG92bw%3D%3D (текст сообщения rawurlencoded base64_encoded в кодировке utf-8)
  # _sms_price = 12.34 (ваша прибыль с данного смс сообщения в системе СМС Доступ в рублях)
  # _sms_exchrate = 25.00 (текущий курс отношения рубля к доллару в системе СМС Доступ)
  # _sms_trusted = 3 (опциональный параметр, с указанием доверия номеру абонента в виде цифры от 0 до 10)
  # _abonent_price = 2.87 (параметр указывающий стоимость смс для абонента в валюте указанной в параметре _abonent_price_currency)
  # _abonent_price_currency = RUR (параметр указывает валюту в которой было произведено списание с абонента за отправленную смс)
  # _sms_parts = 1 (опциональный параметр, указывающий на количество частей из которых состояло смс сообщение *)
  # _sms_operator_id = 1 (уникальный идентификатор оператора в системе СМС Доступ)
  # _spec_id = 1 (указание на источник запроса, используется в проверке уникальности, целое число, может быть 0) **
  # _sms_date = 2009-01-23 12:34:56 (дата регистрации СМС платформой)
  # Все параметры кроме _is_debug, _sms_trusted, _sms_parts должны присутствовать в переданном Вам запросе.
  # Далее требуется сделать проверку целостности пришедших Вам данных с использованием вашего ключа. Используя функцию md5, нужно скомпоновать строку с параметрами:
  # project_md5 + _session_code + _sms_id + _sms_number + _sms_operator + _sms_phone + _sms_message + _sms_price
  # Эта строка должна совпадать с переменной _md5_hash, которую Вам передали в запросе.
  def parse_payment_params
    @payment_params = HashWithIndifferentAccess.new
    params.each do |key, value|
      if key.starts_with?('_')
        @payment_params[key.gsub(/^_/, "").downcase] = value
      end
    end

  end

  # Отдаем результат в cp1251
  def this_xml_needs_to_be_in_cp1251
    response.charset = 'cp1251'
    response.body = Iconv.conv('cp1251//IGNORE//TRANSLIT','UTF-8',response.body)
  end
end

# 	_is_debug = 1 // Параметр тестирования проекта, по-умолчанию не передается
# 	_md5_hash = a123456789b123456789c123456789d1 // Ключ проверки целостности данных
# 	_session_code = a123456789b123456789c123456789d1 // Ключ текущей сессии
# 	_sms_id=1234567890 // Уникальный идентификатор смс сообщения
# 	_sms_number=1234 // Короткий номер на который прислано смс сообщение
# 	_sms_operator=Megafon // Название оператора, латиница, короткое
# 	_sms_operator_full=Megafon_moscow // Название оператора, латиница, полное
# 	_sms_phone=7912xxxx345 // Номер абонента приславшего смс сообщение
# 	_sms_country=ru // Страна абонента приславшего смс сообщение
# 	_sms_message=ttslovo // Полный текст сообщения
# 	_sms_plain=dHRzbG92bw%3D%3D // Текст сообщения rawurlencoded base64_encoded в кодировке utf-8
# 	_sms_price=12.34 // Ваша прибыль с данного смс сообщения в системе СМС Доступ в рублях
# 	_sms_exchrate=25.00 // Текущий курс отношения рубля к доллару в системе СМС Доступ
# 	_sms_trusted=3 // Опциональный параметр, с указанием доверия номеру абонента в виде цифры от 0 до 10
# 	_abonent_price=2.87 // Параметр указывающий стоимость смс для абонента в валюте указанной в параметре _abonent_price_currency
# 	_abonent_price_currency=RUR // Параметр указывает валюту в которой было произведено списание с абонента за отправленную смс
# 	_sms_parts=1 // Опциональный параметр, указывающий на количество частей из которых состояло смс сообщение
# 		В случае, если параметр _sms_parts присутствует и он больше единицы, то будет произведена тарификация соответственно количеству смс полученных от абонента.
# 		Сумма в параметре _sms_price будет иметь значение полученное по формуле: кол-во_смс * стоимость_смс.
# 		Параметр _abonent_price будет показывать стоимость 1 смс сообщения вне зависимости от количества полученных частей.
# 	_sms_operator_id=1 // Уникальный идентификатор оператора в системе СМС Доступ
# 	_spec_id=1 // Указание на источник запроса, используется в проверке уникальности, целое число, может быть 0
#     _sms_date=2009-01-23 12:34:56 // Дата регистрации СМС платформой

# HTTParty.get("http://localhost:3000/gateway/smsdostup/result",
#          :body => {
#                     :_md5_hash => "40d08850ec56858c03d2750b7c41f509",
#                     :_session_code => 'a123456789b123456789c123456789d1',
#                     :_sms_id => '1234567890',  :_sms_number => 1234, :_sms_operator => 'Megafon', :_sms_operator_full => 'Megafon_moscow',
#                     :_sms_phone => '7912xxxx345', :_sms_country => 'ru', :_sms_message => '77235 DC4FB3',
#                     :_sms_plain => 'dHRzbG92bw%3D%3D', :_sms_price => 12.34 , :_sms_exchrate => 25.00,
#                     :_abonent_price => 2.87, :_abonent_price_currency => 'RUR', :_sms_parts => 1, :_sms_operator_id => 1, :_sms_date => Time.now

#                      })
# "d6cabea3bb7788d58733e4d9c4d777cc""d6cabea3bb7788d58733e4d9c4d777cc"
# Digest::MD5.hexdigest(["628d20facff96a6fed9b47a173f17c9c", 'a123456789b123456789c123456789d1', '1234567890',  '1234', 'Megafon', '7912xxxx345', '77235 DC4FB3', '12.34'].join)
# <?php   "628d20facff96a6fed9b47a173f17c9c"
# if Digest::MD5.hexdigest([@gateway.md5_code,              @payment_params[:session_code], # проверка ключа
#                                 @payment_params[:sms_id],       @payment_params[:sms_number],
#                                 @payment_params[:sms_operator], @payment_params[:sms_phone],
#                                 @payment_params[:sms_message],  @payment_params[:sms_price]].join) == @payment_params[:md5_hash]
# # СМС Доступ 2008
# # Скрипт для ответа на запрос Биллинга

# # Вывод ошибок нежелателен
# ini_set('display_errors', 0);
# error_reporting(0);

# # Задаем ключ (идентификатор) проекта, который указан в разделе 'Список проектов' в вашем аккаунте
# $project_md5 = "628d20facff96a6fed9b47a173f17c9c";

# # Проверяем наличие данных
# if (!isset($_POST['_md5_hash']) || !isset($_POST['_session_code']) || !isset($_POST['_sms_id']) || !isset($_POST['_sms_number']) || !isset($_POST['_sms_operator']) || !isset($_POST['_sms_phone']) || !isset($_POST['_sms_message']) || !isset($_POST['_sms_price']) || !isset($_POST['_sms_message'])) return_result("err void", true);
# if (!$_POST['_md5_hash'] || !$_POST['_session_code'] || !$_POST['_sms_id'] || !$_POST['_sms_number'] || !$_POST['_sms_operator'] || !$_POST['_sms_phone'] || !$_POST['_sms_price']) return_result("err false", true);

# # Проверяем целостность данных
# $_md5hash = md5($project_md5.$_POST['_session_code'].$_POST['_sms_id'].$_POST['_sms_number'].$_POST['_sms_operator'].$_POST['_sms_phone'].stripslashes($_POST['_sms_message']).$_POST['_sms_price']);
# if ($_md5hash != $_POST['_md5_hash']) return_result("err hash", true);

# /* Напоминаем, что в случае наличия параметра _is_debug производится ТЕСТИРОВАНИЕ проекта,
# если Вы ведете внутренние учеты, зачисляете средства и так далее - учтите, эти запросы нами не оплачиваются! */

# # Возвращаем результат и завершаем работу
# return_result(
# 	"Здесь должен быть Ваш ответ клиенту"
# );

# # Делаем все необходимые учеты, проверки и определяем ответ абоненту
# /*
# 	Входящие данные (даны исключительно для ознакомления и не являются действительными):
# 	_is_debug = 1 // Параметр тестирования проекта, по-умолчанию не передается
# 	_md5_hash = a123456789b123456789c123456789d1 // Ключ проверки целостности данных
# 	_session_code = a123456789b123456789c123456789d1 // Ключ текущей сессии
# 	_sms_id=1234567890 // Уникальный идентификатор смс сообщения
# 	_sms_number=1234 // Короткий номер на который прислано смс сообщение
# 	_sms_operator=Megafon // Название оператора, латиница, короткое
# 	_sms_operator_full=Megafon_moscow // Название оператора, латиница, полное
# 	_sms_phone=7912xxxx345 // Номер абонента приславшего смс сообщение
# 	_sms_country=ru // Страна абонента приславшего смс сообщение
# 	_sms_message=ttslovo // Полный текст сообщения
# 	_sms_plain=dHRzbG92bw%3D%3D // Текст сообщения rawurlencoded base64_encoded в кодировке utf-8
# 	_sms_price=12.34 // Ваша прибыль с данного смс сообщения в системе СМС Доступ в рублях
# 	_sms_exchrate=25.00 // Текущий курс отношения рубля к доллару в системе СМС Доступ
# 	_sms_trusted=3 // Опциональный параметр, с указанием доверия номеру абонента в виде цифры от 0 до 10
# 	_abonent_price=2.87 // Параметр указывающий стоимость смс для абонента в валюте указанной в параметре _abonent_price_currency
# 	_abonent_price_currency=RUR // Параметр указывает валюту в которой было произведено списание с абонента за отправленную смс
# 	_sms_parts=1 // Опциональный параметр, указывающий на количество частей из которых состояло смс сообщение
# 		В случае, если параметр _sms_parts присутствует и он больше единицы, то будет произведена тарификация соответственно количеству смс полученных от абонента.
# 		Сумма в параметре _sms_price будет иметь значение полученное по формуле: кол-во_смс * стоимость_смс.
# 		Параметр _abonent_price будет показывать стоимость 1 смс сообщения вне зависимости от количества полученных частей.
# 	_sms_operator_id=1 // Уникальный идентификатор оператора в системе СМС Доступ
# 	_spec_id=1 // Указание на источник запроса, используется в проверке уникальности, целое число, может быть 0
#     _sms_date=2009-01-23 12:34:56 // Дата регистрации СМС платформой
# */

# # Обработка входящего сообщения.
# # Для получения текста сообщения Вам потребуется произвести следующие операции:
# /*
# $message_text = rawurldecode($_POST['_sms_plain']); // Убрать URL-кодирование
# $message_text = base64_decode($message_text); // Перевести данные из MIME base64
# $message_text = iconv("utf-8", "cp1251", $message_text); // Поменять кодировку с utf-8 на cp1251
# $message_text = stripslashes($message_text); // Удалить возможные слэш символы
# */

# # Для большего удобства так же передается параметр _sms_message в котором все эти действия уже произведены,
# # но если же сообщения приходящие Вам достаточно большие, включают в себя спец символы и русский язык, то лучше работать с параметром _sms_plain

# # Ваша проверка данных и учет в системе
# # ! В случае если получен параметр _is_debug, то учет в системе делать не следует. Был произведен тест скрипта на работоспособность.
# # ! вернуть ответ в случае наличия параметра _is_debug необходимо в следующем формате <SMSDOSTUP>OK</SMSDOSTUP>

# # Выдаем ответ для передачи клиенту
# # ! Учтите обязательность наличия открывающегося <SMSDOSTUP> и закрывающегося </SMSDOSTUP> тегов
# # Содержимое внутри тегов и будет передано клиенту, в случае неверного формата ответа, смс не будет засчитана
# # При ответе используйте кодировку Windows-1251

# # Функция передачи данных
# function return_result($message, $is_error = false) {
# 	if ($is_error) exit("<SMSDERR>".stripslashes($message)."</SMSDERR>");
# 	exit("<SMSDOSTUP>".stripslashes($message)."</SMSDOSTUP>");
# }
# ?>
#     Описание работы скрипта обработчика

# Схема работы скрипта достаточно проста. Абонент отправляет смс сообщение на один из наших коротких номеров. Наша система получает это сообщение и определяет принадлежит ли оно Вашему проекту. В случае успеха система передает данные этого смс сообщения (текст, телефон, стоимость и т.д.) на URL указанный при регистрации проекта. Именно по этому адресу должен быть расположен Ваш скрипт обработчика запросов, который выдаст нашей системе ответ для абонента.
# Пример: абонент отправляет смс сообщение TTPOGODA на номер 4161, система передает Вам это сообщение, и Ваш скрипт отвечает на запрос текстом: "Пасмурно, +7 градусов". Данный текст будет передан абоненту.

# Для того чтобы Ваш скрипт составил правильный ответ на запрос системы, требуется выполнить несколько операций. Для начала необходимо указать в параметре project_md5 ключ Вашего нового проекта, который будет участвовать в проверке пришедшего запроса. Так как Ваш скрипт для приема сообщений должен быть доступен извне, то необходимо ограничить доступ к скрипту. Тогда злоумышленники не смогут сформировать запрос на Ваш скрипт и получить данные (например, пароль доступа). Именно для этих целей и служит ключ проекта. Этот уникальный 32 символьный шифр не публикуется и известен только Вам и нашему сервису. Таким образом, с помощью этого кода мы и будем проводить проверку информации.

# Теперь можно приступать к проверке пришедших параметров. Список передаваемых Вашему скрипту параметров содержит следующие элементы:
# _is_debug = 1 (параметр тестирования проекта, по-умолчанию не передается)
# _md5_hash = a123456789b123456789c123456789d1 (ключ проверки целостности данных)
# _session_code = 9194ac153d8421a161b7ef17ga80a1f3 (ключ текущей сессии)
# _sms_id =1234567890 (уникальный идентификатор смс сообщения) **
# _sms_number = 1234 (короткий номер, на который прислано смс сообщение)
# _sms_operator = Megafon (название оператора, латиница, короткое)
# _sms_operator_full = Megafon_moscow (название оператора, латиница, полное)
# _sms_phone = 7912xxxx345 (номер абонента, приславшего смс сообщение)
# _sms_country = ru (страна абонента, приславшего смс сообщение)
# _sms_message = ttpogoda (полный текст сообщения)
# _sms_plain = dHRzbG92bw%3D%3D (текст сообщения rawurlencoded base64_encoded в кодировке utf-8)
# _sms_price = 12.34 (ваша прибыль с данного смс сообщения в системе СМС Доступ в рублях)
# _sms_exchrate = 25.00 (текущий курс отношения рубля к доллару в системе СМС Доступ)
# _sms_trusted = 3 (опциональный параметр, с указанием доверия номеру абонента в виде цифры от 0 до 10)
# _abonent_price = 2.87 (параметр указывающий стоимость смс для абонента в валюте указанной в параметре _abonent_price_currency)
# _abonent_price_currency = RUR (параметр указывает валюту в которой было произведено списание с абонента за отправленную смс)
# _sms_parts = 1 (опциональный параметр, указывающий на количество частей из которых состояло смс сообщение *)
# _sms_operator_id = 1 (уникальный идентификатор оператора в системе СМС Доступ)
# _spec_id = 1 (указание на источник запроса, используется в проверке уникальности, целое число, может быть 0) **
# _sms_date = 2009-01-23 12:34:56 (дата регистрации СМС платформой)
# Все параметры кроме _is_debug, _sms_trusted, _sms_parts должны присутствовать в переданном Вам запросе.
# Далее требуется сделать проверку целостности пришедших Вам данных с использованием вашего ключа. Используя функцию md5, нужно скомпоновать строку с параметрами:
# project_md5 + _session_code + _sms_id + _sms_number + _sms_operator + _sms_phone + _sms_message + _sms_price
# Эта строка должна совпадать с переменной _md5_hash, которую Вам передали в запросе.

# Для получения текста сообщения Вам потребуется произвести следующие операции: убрать URL-кодирование (rawurldecode в php), перевести данные из MIME base64 (base64_decode в php)
# поменять кодировку с utf-8 на cp1251 (iconv в php). Для большего удобства так же передается параметр _sms_message в котором все эти действия уже произведены, но если же сообщения приходящие Вам достаточно большие, включают в себя спец символы и русский язык, то лучше работать с параметром _sms_plain.

# В случае если получен параметр _is_debug, то учет в системе делать не следует. Был произведен тест скрипта на работоспособность.

# Если все проверки пройдены успешно, можно обрабатывать данные по Вашему усмотрению. В итоге Ваш скрипт должен выдать ответ, который будет содержаться в тэгах <SMSDOSTUP></SMSDOSTUP>.
# Пример: <SMSDOSTUP>Vash kod: 12345</SMSDOSTUP>.

# Важно:
# - В ответе следует использовать кодировку Windows-1251;
# - Текст вне тэгов <SMSDOSTUP></SMSDOSTUP> будет проигнорирован;
# - Параметр _sms_phone содержит номер с частично скрытыми цифрами.

# * В случае, если параметр _sms_parts присутствует и он больше единицы, то будет произведена тарификация соответственно количеству смс полученных от абонента.
# Сумма в параметре _sms_price будет иметь значение полученное по формуле: кол-во_смс * стоимость_смс.
# Параметр _abonent_price будет показывать стоимость 1 смс сообщения вне зависимости от количества полученных частей.

# ** Важно. В случае если Ваш скрипт не ответил на наш запрос с первого раза (к примеру по причине долгой обработки смс с Вашей стороны), нашим сервером производится повторная отправка. Имейте ввиду этот факт при учете статистики со своей стороны.
# В этом случае Вам требуется выдать ответ на наш запрос и проверить отсутствие повторной обработки смс со своей стороны (к примеру в случае если Вы зачисляете средства своему партнеру).
# Для того, чтобы определить наличие повторного запроса требуется проверить нет ли у Вас в базе данных информации по указанному параметру _sms_id в рамках параметра _spec_id.
# Примеры запросов:
# _sms_id=123 и _spec_id=0 => уникален
# _sms_id=123 и _spec_id=1 => уникален
# _sms_id=124 и _spec_id=1 => уникален
# _sms_id=123 и _spec_id=0 => повторный запрос, пересекается с первым примером
