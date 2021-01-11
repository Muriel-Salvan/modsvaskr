module ModsvaskrTest

  module TestsSuites

    class InGameTestsSuite < Modsvaskr::TestsSuite

      class << self
        attr_accessor *%i[tests in_game_tests_for parse_auto_tests_statuses_for]
      end

      # Discover the list of tests information that could be run.
      # [API] - This method is mandatory
      #
      # Result::
      # * Hash< String, Hash<Symbol,Object> >: Ordered hash of test information, per test name
      def discover_tests
        InGameTestsSuite.tests
      end

      # Get the list of tests to be run in-game for a given list of test names.
      # [API] - This method is mandatory for tests needing to be run in-game.
      #
      # Parameters::
      # * *tests* (Array<String>): List of test names
      # Result::
      # * Hash<Symbol, Array<String> >: List of in-game test names, per in-game tests suite
      def in_game_tests_for(tests)
        InGameTestsSuite.in_game_tests_for.nil? ? {} : InGameTestsSuite.in_game_tests_for.call(tests)
      end

      # Set statuses based on the result of AutoTest statuses.
      # AutoTest names are case insensitive.
      # [API] - This method is mandatory for tests needing to be run in-game.
      #
      # Parameters::
      # * *tests* (Array<String>): List of test names
      # * *auto_test_statuses* (Hash<Symbol, Array<[String, String]> >): Ordered list of AutoTest [test name, test status], per AutoTest tests suite
      # Result::
      # * Array<[String, String]>: Corresponding list of [test name, test status]
      def parse_auto_tests_statuses_for(tests, auto_test_statuses)
        InGameTestsSuite.parse_auto_tests_statuses_for.nil? ? [] : InGameTestsSuite.parse_auto_tests_statuses_for.call(tests, auto_test_statuses)
      end

    end

  end

end
