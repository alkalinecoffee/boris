class Hash
  def clean_string_values_in_hash
    self.each_pair do |key, val|
      val.clean_string_values_in_array if val.is_a?(Array)
      self[key] = val.strip.clean_string if val.is_a?(String)
    end
  end
end