module ModsvaskrTest

  module TestsSuites

    class TestsSuite < Modsvaskr::TestsSuite

      class << self
        attr_accessor *%i[tests mocked_statuses]
      end

      # Discover the list of tests information that could be run.
      # [API] - This method is mandatory
      #
      # Result::
      # * Hash< String, Hash<Symbol,Object> >: Ordered hash of test information, per test name
      def discover_tests
        TestsSuite.tests
      end

      # Run a given test and get back its status
      # [API] - This method is mandatory for tests needing to be run immediately.
      #
      # Parameters::
      # * *test_name* (String): Test to be run
      # Result::
      # * String: Test status
      def run_test(test_name)
        TestsSuite.mocked_statuses[test_name]
      end

    end

  end

end
