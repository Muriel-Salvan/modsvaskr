module Modsvaskr

  # Mixin adding methods to map directly a tests suite to an in-game tests suite
  # Uses the following methods:
  # * *in_game_tests_suite* -> Symbol: Name of the in-gamer tests suite on which we forward the tests run
  module InGameTestsSuite

    # Get the list of tests to be run in-game for a given list of test names.
    # [API] - This method is mandatory for tests needing to be run in-game.
    #
    # Parameters::
    # * *tests* (Array<String>): List of test names
    # Result::
    # * Hash<Symbol, Array<String> >: List of in-game test names, per in-game tests suite
    def in_game_tests_for(tests)
      { in_game_tests_suite => tests }
    end

    # Set statuses based on the result of AutoTest statuses.
    # AutoTest names are case insensitive.
    # [API] - This method is mandatory for tests needing to be run in-game.
    #
    # Parameters::
    # * *tests* (Array<String>): List of test names
    # * *auto_test_statuses* (Hash<Symbol, Hash<String, String> >): In-game test statuses, per in-game test name, per in-game tests suite
    # Result::
    # * Array<[String, String]>: Corresponding list of [test name, test status]
    def parse_auto_tests_statuses_for(tests, auto_test_statuses)
      in_game_test_statuses = auto_test_statuses[in_game_tests_suite] || {}
      tests.map do |test_name|
        test_downcase = test_name.downcase
        _in_game_test, in_game_test_status = in_game_test_statuses.find { |search_in_game_test, _search_in_game_test_status| search_in_game_test.downcase == test_downcase }
        in_game_test_status.nil? ? nil : [test_name, in_game_test_status]
      end.compact
    end

  end

end
