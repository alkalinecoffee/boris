require 'setup_tests'

class ArrayTest < Test::Unit::TestCase
  context 'the Array class' do
    should 'return the product key for a microsoft product via #to_ms_product_key' do
      product_key_binary = [164, 1, 1, 0, 3, 0, 0, 0, 53, 53, 48, 52, 49, 45, 49, 56, 54, 45, 48, 49, 51, 51, 48,
        51, 53, 45, 55, 53, 55, 54, 51, 0, 151, 0, 0, 0, 88, 49, 52, 45, 50, 51, 56, 57, 54, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

      assert_equal('BBBBB-BBBBB-BBBBB-BBBBB-BBBBB', product_key_binary.to_ms_product_key)
    end

    should 'return each item of an array as a nil-values key-value pair via #to_nil_hash' do
      assert_equal({:value_one=>nil, :value_two=>nil}, ['value_one', 'value_two'].to_nil_hash)
    end

    should 'return the wwn of an array via #to_wwn' do
      assert_equal('00000000aaaaaaaa', [0, 0, 0, 0, 170, 170, 170, 170].to_wwn)
    end

    should 'recursively strip the string values within an array via #strip_string_values_in_array' do
      assert_equal([1, 'a', 'c', ['x', 'y']], [1, 'a ', ' c ', [' x ', ' y ']].strip_string_values_in_array)
    end
  end
end