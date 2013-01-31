class String
  include Boris

  def after_colon
    generic_after(':')
  end

  def after_period
    generic_after('\.')
  end

  def after_pipe
    generic_after('|')
  end

  def after_slash
    generic_after('\\\\|\/')
  end

  def before_colon
    generic_before(':')
  end

  def before_period
    generic_before('\.')
  end

  def before_pipe
    generic_before('|')
  end

  def before_slash
    generic_before('\\\\|\/')
  end  

  def between_parenthesis
    x = self.scan(/\((.*)\)/)
    return x.empty? ? nil : x.join
  end

  def format_model
    return nil if self == ''

    # delete models containing "server" or beginning with "ibm"
    # also remove configuration numbers appended (typically on IBM
    # products... ex 'System x1000 M3 -[123456]-')
    model = self.gsub(/(^ibm|server)/i, '').split(/-*(\[|\()/)[0]

    model = if model =~ /^sun.*blade/i
      'SunBlade ' + model.scan(/\d/).join
    elsif model =~ /^sun.*fire/i
      'SunFire ' + model.scan(/\d/).join
    elsif model =~ /^T\d{4}/
      'SPARC Enterprise ' + model
    elsif model =~ /^big-*ip/i
      model.sub(/^big-*ip/i, 'BIG-IP')
    elsif model =~ /^wsc\d{4}-*.*/i
      'Catalyst ' + (model.scan(/\d/).join + '-' + model.scan(/[a-z]$/i).join).sub(/-$/, '')
    else
      model
    end

    model.strip
  end

  def format_serial
    return nil if self =~ /(^$|\(*none\)*)/i

    self.upcase
  end

  def string_clean
    # remove registered "(R)" mark
    string = self.gsub(/\(r\)/i, '')

    string.encode(Encoding.find('ASCII'), :undef=>:replace, :replace=>'').strip
  end

  def format_vendor
    return nil if self == ''
    
    vendor = self

    vendor = if vendor =~ /^(amd|authenticamd)/i;       VENDOR_AMD
    elsif vendor =~ /^brocade/i;                        VENDOR_BROCADE
    elsif vendor =~ /^citrix/i;                         VENDOR_CITRIX
    elsif vendor =~ /^dell/i;                           VENDOR_DELL
    elsif vendor =~ /^emulex/i;                         VENDOR_EMULEX
    elsif vendor =~ /^(compaq|hp|hewlett packard)/i;    VENDOR_HP
    elsif vendor =~ /^ibm/i;                            VENDOR_IBM
    elsif vendor =~ /^(genuineintel|intel )/i;          VENDOR_INTEL
    elsif vendor =~ /^(microsoft)/i;                    VENDOR_MICROSOFT
    elsif vendor =~ /^(oracle|sun[w]*|sun microsys)/i;  VENDOR_ORACLE
    elsif vendor =~ /^qlogic/i;                         VENDOR_QLOGIC
    elsif vendor =~ /^red\s*hat/i;                      VENDOR_REDHAT
    elsif vendor =~ /^suse linux/i;                     VENDOR_SUSE
    elsif vendor =~ /^vmware/i;                         VENDOR_VMWARE
    else vendor
    end

    vendor.strip
  end

  def generic_after(delimiter)
    x = self.scan(/^.*[#{delimiter}](.*)$/)
    return x.empty? ? nil : x.join.strip
  end

  def generic_before(delimiter)
    x = self.scan(/^(.*?)[#{delimiter}]/)
    return x.empty? ? nil : x.join.strip
  end

  def hex_to_address
    self.scan(/../).map {|octet| octet.hex}.join('.')
  end
  
  def remove_arch
    String.new(self).remove_arch!
  end

  def remove_arch!
    self.replace(self.gsub(/\s+\(*(32|64)(-|\s)*bit\)*/, ''))
  end

  def within_quotes
    x = self.scan(/["|'](.*?)["|']/).flatten
    return x.empty? ? nil : x
  end
end