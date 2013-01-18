require 'setup_tests'

class HashTest < Test::Unit::TestCase
  context 'the Hash class' do
    should 'recursivley strip the string values inside of a Hash via #strip_string_values_in_hash' do
      assert_equal({:someval=>'strip this', :somearray=>['this too!']},
        {:someval=>' strip this ', :somearray=>[' this too!']}.strip_string_values_in_hash)
    end
  end
end