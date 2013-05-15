require 'boris/helpers/constants'

class String
  include Boris

  # Returns the string value found after the last colon symbol from self.
  #
  #  'A:B:C'.after_colon  #=> "C"
  #
  # @return [Nil, String] string if value found, else returns nil
  def after_colon
    value_after_character(':')
  end

  # Returns the string value found after the last period symbol from self.
  #
  #  'A.B.C'.after_period  #=> "C"
  #
  # @return [Nil, String] string if value found, else returns nil
  def after_period
    value_after_character('\.')
  end

  # Returns the string value found after the last pipe symbol from self.
  #
  #  'A|B|C'.after_pipe  #=> "C"
  #
  # @return [Nil, String] string if value found, else returns nil
  def after_pipe
    value_after_character('|')
  end

  # Returns the string value found after the last slash (both forwards
  # and backwards) symbol from self.
  #
  #  'A/B/C'.after_slash  #=> "C"
  #  'A\B\C'.after_slash  #=> "C"
  #
  # @return [Nil, String] string if value found, else returns nil
  def after_slash
    value_after_character('\\\\|\/')
  end

  # Returns the string value found before the first colon symbol from self.
  #
  #  'A:B:C'.before_colon  #=> "A"
  #
  # @return [Nil, String] string if value found, else returns nil
  def before_colon
    value_before_character(':')
  end

  # Returns the string value found before the first period symbol from self.
  #
  #  'A.B.C'.before_period  #=> "A"
  #
  # @return [Nil, String] string if value found, else returns nil
  def before_period
    value_before_character('\.')
  end

  # Returns the string value found before the first pipe symbol from self.
  #
  #  'A.B.C'.before_period  #=> "A"
  #
  # @return [Nil, String] string if value found, else returns nil
  def before_pipe
    value_before_character('|')
  end

  # Returns the string value found before the first slash (both forwards
  # and backwards) symbol from self.
  #
  #  'A/B/C'.before_slash  #=> "A"
  #  'A\B\C'.before_slash  #=> "A"
  #
  # @return [Nil, String] string if value found, else returns nil
  def before_slash
    value_before_character('\\\\|\/')
  end

  # Returns the string value found between a pair of curly brackets from self.
  #
  #  'A{B}C'.between_curlies  #=> "B"
  #
  # @return [Nil, String] string if value found, else returns nil
  def between_curlies
    self.extract(/\{(.*)\}/)
  end

  # Returns the string value found between a pair of parenthesis from self.
  #
  #  'A(B)C'.between_parenthesis  #=> "B"
  #
  # @return [Nil, String] string if value found, else returns nil
  def between_parenthesis
    self.extract(/\((.*)\)/)
  end

  # Returns the string value found between a pair of quotes (single or double)
  # from self.
  #
  #  'A"B"C'.between_quotes  #=> "B"
  #
  # @return [Nil, String] string if value found, else returns nil
  def between_quotes
    self.extract(/["|'](.*?)["|']/)
  end

  # Cleans self by stripping leading/trailing spaces, any consecutive spaces, and
  # removing any ASCII characters that are sometimes reported by devices.  Also
  # removes registered (R) characters.
  #
  #  'Microsoft(R) Windows(R)'.clean_string             #=> "Microsoft Windows"
  #  "string with\u00A0 weird character".clean_string  #=> "string with weird character"
  #
  # @return [String] the cleaned up string
  def clean_string
    # remove registered "(R)" and trademark "(tm)" marks
    string = self.gsub(/\(r\)|\(tm\)/i, '')
    string.gsub!(/\s+/, ' ')

    string.encode(Encoding.find('ASCII'), :undef=>:replace, :replace=>'').strip
  end

  # Attempts to pull only the first match inside the parenthesis for a given
  # regex.  It's similar to using String#match or String#scan..join to extract
  # the first matching value (that is, the value to match on found within the
  # parenthesis in the regex).
  #
  #  'abcdef'.extract(/ab(cd)ef/)  #=> "cd"
  #  'abcdef'.extract(/abcdef/)  #=> nil
  #
  # @return [String, NilClass] the matched string, else returns nil
  def extract(regex)
    self[regex, 1]
  end

  # Attempts to grab the hardware model from self and formats it for
  # consistency to match the marketing model name as specified from the vendor.
  # Particularly on UNIX systems, the hardware model is not reported in a
  # consistent manner across all systems (even those from the same vendor).
  # This method is used when scrubbing a Target's retrieved data before
  # outputting it to the user.  Returns self if the provided model did not match
  # any of the known model formats used within this method.
  #
  #  'sun fire 400'.format_model  #=> "SunFire 400"
  #  't1000'.format_model  #=> "SPARC Enterprise T1000"
  #
  # @return [String] the formatted model, else returns self
  def format_model
    return self if self == ''

    # delete models containing "server" or beginning with "ibm"
    # also remove configuration numbers appended (typically on IBM
    # products... ex 'System x1000 M3 -[123456]-')
    model = self.gsub(/(^ibm|server)/i, '').split(/-*(\[|\()/)[0]

    model = if model =~ /^sun.*blade/i
      'SunBlade ' + model.extract(/(\d+)/)
    elsif model =~ /^sun.*fire/i
      'SunFire ' + model.extract(/(\d+)/)
    elsif model =~ /^T\d{4}/
      'SPARC Enterprise ' + model
    elsif model =~ /^big-*ip/i
      model.sub(/^big-*ip/i, 'BIG-IP')
    elsif model =~ /^wsc\d{4}-*.*/i
      model.sub!(/wsc/i, 'Catalyst ')
      model.include?('-') ? model : model.sub(/(\d{4})(.*)/) {$2.empty? ? "#{$1}" : "#{$1}-#{$2}" }
    else
      model
    end

    model.strip
  end

  # Formats self to fit a consistent serial number format (no special characters,
  # uppercased).
  #
  #  'abcd1234 '.format_serial  #=> "ABCD1234"
  #  '(none)'.format_serial  #=> nil
  #
  # @return [Nil, String] the formatted serial, else returns nil if the serial
  #   does not seem legit
  def format_serial
    return nil if self =~ /(^$|\(*none\)*)/i

    self.clean_string.upcase
  end

  # Attempts to grab the hardware vendor name from self and formats it for
  # consistency to match the vendor's corproate name as specified from the
  # vendor. This method is used when scrubbing a Target's retrieved data before
  # outputting it to the user.  Returns self if the provided vendor name did
  # not match any of the known vendor formats used within this method.
  #
  #  'hewlett packard'.format_vendor  #=> "Hewlett Packard Inc."
  #  'sun microsystems'.format_vendor  #=> "Oracle Corp."
  #
  # @return [String] the formatted vendor
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

  # Returns the IP address value derived from self in hex format.
  #
  #  'ffffff00'.hex_to_ip_address  #=> "255.255.255.0"
  #
  # @return [Nil, String] returns the IP address
  def hex_to_ip_address
    self.scan(/../).map {|octet| octet.hex}.join('.')
  end

  # Pads self with leading zeros if needed.  Useful for properly formatting a String
  # (usually from the ps command in UNIX representing elapsed time) to a more complete,
  # zero-padded string to the format dd-hh:mm:ss.  mm::ss is the bare-minimum required
  # String.
  #
  #  '00:01'.pad_elapsed_time  #=> '00-00:00:01'
  #  '01:01'.pad_elapsed_time  #=> '00-00:01:01'
  #  '01:01:01'.pad_elapsed_time  #=> '00-01:01:01'
  #  '1-01:00:01'.pad_elapsed_time  #=> '01-01:01:01'
  #
  # @return String the padded elapsed time
  def pad_elapsed_time
    return self if self =~ /\d{2}\-\d{2}:\d{2}:\d{2}/

    return "0#{self}" if self =~ /\d{1}-/

    case self.count(':')
    when 2; "00-#{self}"
    when 1; "00-00:#{self}"
    end
  end

  # Pads self with leading zeros if needed.  Useful for properly formatting MAC addresses.
  # Takes an optional delimiter used for splitting and returning the provided string in
  # the proper format. The string to be formatted is expected to already be in a six-octet
  # format.
  #
  #  '0:0:0:0:0:AA'.pad_mac_address  #=> "00:00:00:00:00:AA"
  #  '0-0-0-0-AA-12'.pad_mac_address('-')  #=> "00-00-00-00-AA-12"
  #
  # @param delimiter an optional delimiter for the MAC address (default is ':')
  # @return [String] the padded MAC address
  def pad_mac_address(delimiter=':')
    self.split(delimiter).inject([]) do |mac, octet|
      octet.length == 1 ? mac << "0#{octet}" : mac << octet
    end.join(delimiter).upcase
  end
  
  # Returns a new string with the architecture removed. See {String#remove_arch!}.
  #
  #  "Windows Server 2003 (64-bit)".remove_arch #=> "Windows Server 2003"
  #
  # @return [String] returns a new string with architecture rmeoved
  def remove_arch
    String.new(self).remove_arch!
  end

  # Removes the architecture in place. See {String#remove_arch}.
  #
  # @return [String] returns self with architecture rmeoved
  def remove_arch!
    self.replace(self.gsub(/\s+\(*(32|64)(-|\s)*bit\)*/, ''))
  end

  # Allows you to specify your own delimiter to grab the string value found
  # after the last delimiter.  It's mainly used internally with the
  # #after_ helper methods.
  #
  #   'A&B&C'.value_after_character('&')  #=> "C"
  #
  # @param delimiter
  # @return [Nil, String] returns the found value, else returns nil
  def value_after_character(delimiter)
    x = self.extract(/^.*[#{delimiter}](.*)$/)
    x.nil? ? nil : x.strip
  end

  # Allows you to specify your own delimiter to grab the string value found
  # before the first delimiter.  It's mainly used internally with the
  # #after_ helper methods.
  #
  #   'A&B&C'.value_before_character('&')  #=> "A"
  #
  # @param delimiter
  # @return [Nil, String] returns the found value, else returns nil
  def value_before_character(delimiter)
    x = self.extract(/(.*?)[#{delimiter}]/)
    x.nil? ? nil : x.strip
  end
end