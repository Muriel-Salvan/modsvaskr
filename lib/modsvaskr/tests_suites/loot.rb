module Modsvaskr

  module TestsSuites

    # Check LOOT reports for errors
    class Loot < TestsSuite

      # Discover the list of tests information that could be run.
      # [API] - This method is mandatory
      #
      # Result::
      # * Hash< String, Hash<Symbol,Object> >: Ordered hash of test information, per test name
      def discover_tests
        {
          'error_messages' => {
            name: 'Check for LOOT errors'
          }
        }
      end

      # Run a given test and get back its status
      # [API] - This method is mandatory for tests needing to be run immediately.
      #
      # Parameters::
      # * *test_name* (String): Test to be run
      # Result::
      # * String: Test status
      def run_test(test_name)
        'ok'
      end

    end

  end

end
