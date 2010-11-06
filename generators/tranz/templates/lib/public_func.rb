module PublicFunc

  def random_password(size=10)
    chars = ('a'..'z').to_a
    (1..size).collect{|a| chars[rand(chars.size)] }.join
  end

  def sum_field_model(model, field)
    sum = 0
    model.each{ |x| sum += x[field] unless x[field].nil? }
    return sum
  end

end
