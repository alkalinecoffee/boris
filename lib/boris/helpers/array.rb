class Array
  def clean_string_values_in_array
    self.map! do |val|
      val.clean_string_values_in_array if val.is_a?(Array)
      val.clean_string_values_in_hash if val.is_a?(Hash)
      val.is_a?(String) ? val.strip.clean_string : val
    end
  end
  
  def to_ms_product_key
    valid_chars = 'BCDFGHJKMPQRTVWXY2346789'.scan(/./)

    product_key = nil
    
    raw_product_key = []

    52.upto(66) do |idx|
      raw_product_key << self[idx]
    end

    24.downto(0) do |a|
      b = 0

      14.downto(0) do |c|
        b = b * 256 ^ raw_product_key[c]
        raw_product_key[c] = (b / 24).to_i
        b = b.remainder(24)
      end

      product_key = "#{valid_chars[b]}#{product_key}"

      if a.remainder(5) == 0 && a != 0
        product_key = "-#{product_key}"
      end
    end

    return product_key.upcase
  end

  def to_nil_hash
    h = Hash.new
    self.each do |item|
      if item.kind_of?(Hash)
        h.merge!(item)
      else
        h[item.to_sym] = nil
      end
    end
    return h
  end

  def to_wwn
    wwn = []

    0.upto(7) do |i|
      hex = self[i].to_s(16)
      hex = "0#{hex}" if self[i] < 16
      wwn << hex
    end
    
    return wwn.join
  end
end