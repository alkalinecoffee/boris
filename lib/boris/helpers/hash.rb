class Hash
  def strip_string_values_in_hash
    self.each_pair do |key, val|
      val.strip_string_values_in_array if val.is_a?(Array)
      self[key] = val.strip if val.is_a?(String)
    end
  end
end