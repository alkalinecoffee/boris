require 'setup_tests'

class StringTest < Test::Unit::TestCase
  context 'the String class' do
    should 'return the last chunk of text after a colon via #after_colon' do
      assert_equal('C', 'AB:C'.after_colon)
      assert_equal('C', 'A:B:C'.after_colon)
      assert_equal(nil, 'ABC'.after_colon)
    end

    should 'return the last chunk of text after a period via #after_period' do
      assert_equal('C', 'AB.C'.after_period)
      assert_equal('C', 'A.B.C'.after_period)
      assert_equal(nil, 'ABC'.after_period)
    end

    should 'return the last chunk of text after a pipe via #after_pipe' do
      assert_equal('C', 'AB|C'.after_pipe)
      assert_equal('C', 'A|B|C'.after_pipe)
      assert_equal(nil, 'ABC'.after_pipe)
    end

    should 'return the last chunk of text after a slash via #after_slash' do
      assert_equal('C', 'A/B/C'.after_slash)
      assert_equal('C', 'A\B\C'.after_slash)
      assert_equal(nil, 'ABCD'.after_slash)
    end

    should 'return the first chunk of text before a colon via #before_colon' do
      assert_equal('AB', 'AB:C'.before_colon)
      assert_equal('A', 'A:B:C'.before_colon)
      assert_equal(nil, 'ABC'.before_colon)
    end

    should 'return the first chunk of text before a period via #before_period' do
      assert_equal('AB', 'AB.C'.before_period)
      assert_equal('A', 'A.B.C'.before_period)
      assert_equal(nil, 'ABC'.before_period)
    end

    should 'return the first chunk of text after a pipe via #before_pipe' do
      assert_equal('AB', 'AB|C'.before_pipe)
      assert_equal('A', 'A|B|C'.before_pipe)
      assert_equal(nil, 'ABC'.before_pipe)
    end

    should 'return the first chunk of text after a slash via #before_slash' do
      assert_equal('A', 'A/B/C'.before_slash)
      assert_equal('A', 'A\B\C'.before_slash)
      assert_equal(nil, 'ABCD'.before_slash)
    end

    should 'return the value between a pair of parenthesis via #between_parenthesis' do
      assert_equal('a test string', 'this is (a test string)'.between_parenthesis)
      assert_equal('', 'this is a test () string'.between_parenthesis)
      assert_equal(nil, 'this is a test'.between_parenthesis)
    end

    should 'return the proper name of a model via #format_model' do
      assert_equal('Product X 1000', 'Product X 1000 server'.format_model)
      assert_equal('SunBlade 100', 'sun blade 100'.format_model)
      assert_equal('SunFire 100', 'sun fire 100'.format_model)
      assert_equal('SPARC Enterprise T1000', 'T1000'.format_model)
      assert_equal('BIG-IP 1000', 'bigip 1000'.format_model)
      assert_equal('Catalyst 1000', 'WSC1000'.format_model)
      assert_equal('Catalyst 1000-E', 'WSC1000E'.format_model)
      assert_equal('Catalyst 1000-E', 'WSC1000-E'.format_model)
      assert_equal('System x1000 M3', 'IBM System x1000 M3'.format_model)
      assert_equal('System x1000 M3', 'IBM System x1000 M3 -[123456]-'.format_model)
    end

    should 'return the proper serial number via #format_serial' do
      assert_equal('ABC123', 'abc123'.format_serial)
      assert_equal(nil, 'None'.format_serial)
    end

    should 'return the proper name of a vendor via #format_vendor' do
      assert_equal(VENDOR_AMD, 'amd'.format_vendor)
      assert_equal(VENDOR_AMD, 'authenticamd'.format_vendor)
      assert_equal(VENDOR_BROCADE, 'brocade communications'.format_vendor)
      assert_equal(VENDOR_CITRIX, 'citrix'.format_vendor)
      assert_equal(VENDOR_DELL, 'dell'.format_vendor)
      assert_equal(VENDOR_EMULEX, 'emulex'.format_vendor)
      assert_equal(VENDOR_HP, 'compaq'.format_vendor)
      assert_equal(VENDOR_HP, 'hp'.format_vendor)
      assert_equal(VENDOR_HP, 'hp inc'.format_vendor)
      assert_equal(VENDOR_HP, 'hewlett packard'.format_vendor)
      assert_equal(VENDOR_IBM, 'ibm'.format_vendor)
      assert_equal(VENDOR_INTEL, 'genuineintel'.format_vendor)
      assert_equal(VENDOR_INTEL, 'intel corp'.format_vendor)
      assert_equal(VENDOR_MICROSOFT, 'microsoft'.format_vendor)
      assert_equal(VENDOR_ORACLE, 'oracle'.format_vendor)
      assert_equal(VENDOR_ORACLE, 'sun'.format_vendor)
      assert_equal(VENDOR_ORACLE, 'sunw'.format_vendor)
      assert_equal(VENDOR_ORACLE, 'sun microsystems'.format_vendor)
      assert_equal(VENDOR_QLOGIC, 'qlogic'.format_vendor)
      assert_equal(VENDOR_REDHAT, 'redhat'.format_vendor)
      assert_equal(VENDOR_REDHAT, 'red hat'.format_vendor)
      assert_equal(VENDOR_SUSE, 'suse linux'.format_vendor)
      assert_equal(VENDOR_VMWARE, 'vmware'.format_vendor)

      assert_equal('Some other vendor', 'Some other vendor'.format_vendor)
      assert_equal(nil, ''.format_vendor)
    end

    should 'return the ip-formatted value from a string of hex values via #hex_to_ip_address' do
      assert_equal('255.255.255.0', 'ffffff00'.hex_to_ip_address)
    end

    should 'remove the architecture from a string via #remove_arch' do
      assert_equal('Microsoft SQL Server 2008', 'Microsoft SQL Server 2008 32 bit'.remove_arch)
      assert_equal('Microsoft SQL Server 2008', 'Microsoft SQL Server 2008 32-bit'.remove_arch)
      assert_equal('Microsoft SQL Server 2008', 'Microsoft SQL Server 2008 (32-bit)'.remove_arch)
      assert_equal('Microsoft SQL Server 2008', 'Microsoft SQL Server 2008 (64-bit)'.remove_arch)
      assert_equal('Microsoft SQL Server 2008', 'Microsoft SQL Server 2008'.remove_arch)

      test_string = 'Microsoft SQL Server 2008 32 bit'
      test_string.remove_arch!
      assert_equal('Microsoft SQL Server 2008', test_string)
    end

    should 'remove unnecessary characters from a string via #clean_string' do
      assert_equal('this has an invalid character', "this has an invalid\u00A0 character".clean_string)
      assert_equal('this should be stripped', ' this should be stripped '.clean_string)
      assert_equal('this should be stripped', ' this should be stripped '.clean_string)
      assert_equal('registered', 'registered(r)'.clean_string)
    end

    should 'return the value(s) found between at least one pair of single or double quotes via #between_quotes' do
      assert_equal(['C'], 'AB"C"'.between_quotes)
      assert_equal(['A', 'C'], '"A" B "C"'.between_quotes)
      assert_equal(['A', 'C'], "'A' B 'C'".between_quotes)
      assert_equal(nil, 'ABC'.between_quotes)
    end
  end
end