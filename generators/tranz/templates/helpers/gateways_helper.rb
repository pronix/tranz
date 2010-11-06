module GatewaysHelper
  def gateway_index_title(gw)
    ["<h1 class='dotted'>",
     I18n.t("refill_balance", :default => "Refill balance")," - ",
     gw.name,
     "</h1>"
    ].join
  end

  def help_gateway(gw)
    @method = "help_#{@gateway.class.name.demodulize.downcase}"
    self.respond_to?(@method) ? send(@method) : ""
  end

  def help_telegate
    ["<li>",
     content_tag(:label, "Ok url :", :for => "ok_url"),
     content_tag(:span, ok_gateway_telegate_url, :id => "ok_url"  ),
     "</li><li>",
     content_tag(:label, "Info url :", :for => "info_url"),
     content_tag(:span, info_gateway_telegate_url, :id => "info_url"  ),
     "</li><li>",
     content_tag(:label, "Fail url :", :for => "fail_url"),
     content_tag(:span, fail_gateway_telegate_url, :id => "fail_url"  ),
     "</li><li>",
     content_tag(:label, "Status url :", :for => "status_url"),
     content_tag(:span, status_gateway_telegate_url, :id => "status_url"  ),
     "</li>"]
  end
  def help_smsdostup
    ["<li>",
     content_tag(:label, "Url project:", :for => "project_url"),
     content_tag(:span, result_gateway_smsdostup_url, :id => "project_url"  ),
     "</li>"]

  end
  def help_webmoney
    ["<li>",
     content_tag(:label, "Return url :", :for => "result_url"),
     content_tag(:span, payment_result_gateway_webmoney_url, :id => "result_url"  ),
     "</li><li>",
     content_tag(:label, "Success url :", :for => "success_url"),
     content_tag(:span, payment_success_gateway_webmoney_url, :id => "success_url"  ),
     "</li><li>",
     content_tag(:label, "Fail url :", :for => "fail_url"),
     content_tag(:span, payment_fail_gateway_webmoney_url, :id => "fail_url"  ),
    "</li>"]
  end

  def help_paypal
     ["<li>",
     content_tag(:label, "Notification URL :", :for => "notification_url"),
     content_tag(:span, notify_gateway_paypal_url, :id => "notification_url"  ),
     "</li>"]
  end

end
