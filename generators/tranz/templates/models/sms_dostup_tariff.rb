class SmsDostupTariff < ActiveRecord::Base
  belongs_to :sms_dostup_operator
  belongs_to :sms_dostup_country

  class << self
    # Получение тарифа
    # SmsDostupTariff.update_tariffs
    def update_tariffs
      if @sms_dostup = Gateway.smsdostup

        # Получаем тарифы
        @response = HTTParty.get(@sms_dostup.tariff_url, :query =>{ :pid => @sms_dostup.project_id, :md5 => @sms_dostup.md5_code } )
        if @response.code == 200
          xml = @response.body
          doc = Nokogiri::XML(xml)

          @tarrifs =  []
          doc.xpath("//tarifs//item").each   {|x|
           @tarrifs << {
              :country_code    => x.at(".//country")["code"],
              :country_name    => x.at(".//country").text(),
              :number          => x.at(".//number").text(),
              :operatorname    => x.at(".//operatorname").text(),
              :operatorlatin   => x.at(".//operatorlatin").text(),
              :operatorfull    => x.at(".//operatorfull").text(),
              :abonentprice    => x.at(".//abonentprice").text(),
              :price           => x.at(".//price").text(),
              :currency        => x.at(".//currency").text(),
              :usdprice        => x.at(".//usdprice").text(),
              :clientprofit    => x.at(".//clientprofit").text(),
              :clientprofitusd => x.at(".//clientprofitusd").text(),
              :operatorid      => x.at(".//operatorid").text(),
              :ndspercent      => x.at(".//ndspercent").text()

            }
          }

          # Поиск и создание стран
          @countries = []
          @tarrifs.map{ |tarrif|
            if (@sms_dostup_country = @countries.find{ |n| n.code.to_s == tarrif[:country_code]}) ||
                (@sms_dostup_country = SmsDostupCountry.find_by_code(tarrif[:country_code]))
              @countries << @sms_dostup_country
            else
              @countries << SmsDostupCountry.create(:code => tarrif[:country_code], :name => tarrif[:country_name])
            end
          }.compact.uniq

          # Поиск и создание операторов
          @operators =  []
          @tarrifs.map{ |tarrif|
            if (@sms_dostup_operator = @operators.find{ |x| x.id.to_s == tarrif[:operatorid]  } ) ||
                (@sms_dostup_operator = SmsDostupOperator.find_by_id(tarrif[:operatorid]))
              @operators << @sms_dostup_operator
            else
              @country = @countries.find{ |x| x.code == tarrif[:country_code]  }
              if @country
                @sms_dostup_operator = SmsDostupOperator.create do |t|
                  t.id                    = tarrif[:operatorid]
                  t.name                  = tarrif[:operatorname]
                  t.latin_name            = tarrif[:operatorlatin]
                  t.full_name             = tarrif[:operatorfull]
                  t.sms_dostup_country_id =  @country.id
                  end
              end
              @operators <<  @sms_dostup_operator
            end
          }.compact.uniq
          # Подготоваливаем тарифы для занесения в базу
          @tarrif_attrs =  @tarrifs.map{ |tarrif|
            @country = @countries.find{ |x| x.code.to_s == tarrif[:country_code]  }
            @operator = @operators.find{ |x| x.id.to_s == tarrif[:operatorid]  }
            if @country && @operator
              {
                :number                 => tarrif[:number],                # Номер    <number>2151</number>
                :sms_dostup_country_id  => @country.id,                    # страна   <country code="ru">Россия</country>
                :sms_dostup_operator_id => @operator.id,                   # оператор <operatorid>49</operatorid>  <operatorname>СМАРТС (Самара GSM)</operatorname>
                :abonentprice           => tarrif[:abonentprice],          # <abonentprice>3 руб. (RUR) без НДС</abonentprice>
                :price                  => tarrif[:price],                 # <price>3</price>
                :currency               => tarrif[:currency],              # <currency>руб. (RUR)</currency>
                :usdprice               => tarrif[:usdprice],              # <usdprice>0.1</usdprice>
                :clientprofit           => tarrif[:clientprofit],          # <clientprofit>2.68857</clientprofit>
                :clientprofitusd        => tarrif[:clientprofitusd],       # <clientprofitusd>0.08648</clientprofitusd>
                :ndspercent             => tarrif[:ndspercent]             # <ndspercent>18</ndspercent>

              }
            end
          }.compact

          # Удаляем предыдущие тарифы и заполняем новыми
          SmsDostupTariff.transaction do
            SmsDostupTariff.delete_all
            SmsDostupTariff.create(@tarrif_attrs)
          end

        end
      end
    end
  end # end class << self
end

