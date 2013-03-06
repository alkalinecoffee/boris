require 'setup_tests'

class HashTest < Test::Unit::TestCase
  context 'the Hash class' do
    should 'recursivley strip the string values inside of a Hash via #clean_string_values_in_hash' do
      assert_equal({:someval=>'strip this', :somearray=>['this too!']},
        {:someval=>' strip this ', :somearray=>[' this too!']}.clean_string_values_in_hash)
    end
  end
end