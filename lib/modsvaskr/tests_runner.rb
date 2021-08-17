require 'json'
require 'time'
require 'tmpdir'
require 'modsvaskr/tests_suite'
require 'modsvaskr/in_game_tests_runner'

module Modsvaskr

  # Execute a bunch of tests on games
  class TestsRunner

    include Logger

    # Constructor.
    # Default values are for a standard Skyrim SE installation.
    #
    # Parameters::
    # * *config* (Config): Main configuration
    # * *game* (Game): Game for which we run tests
    def initialize(config, game)
      @config = config
      @game = game
      # Parse tests suites
      @tests_suites = Dir.glob("#{__dir__}/tests_suites/*.rb").map do |tests_suite_file|
        tests_suite = File.basename(tests_suite_file, '.rb').to_sym
        require "#{__dir__}/tests_suites/#{tests_suite}.rb"
        [
          tests_suite,
          TestsSuites.const_get(tests_suite.to_s.split('_').collect(&:capitalize).join.to_sym).new(tests_suite, @game)
        ]
      end.to_h
      @tests_info_file = "#{@game.path}/Data/Modsvaskr/Tests/TestsInfo.json"
    end

    # Return tests suites
    #
    # Result::
    # * Array<Symbol>: List of tests suites
    def tests_suites
      @tests_suites.keys.sort
    end

    # Return test names for a given tests suite
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite
    # Result::
    # * Array<String>: Test names of this suite
    def discover_tests_for(tests_suite)
      log "Discover tests for #{tests_suite}"
      discovered_tests = @tests_suites[tests_suite].discover_tests
      # Complete our tests information
      complete_info = tests_info
      discovered_tests.each do |test_name, test_info|
        complete_info[tests_suite] = {} unless complete_info.key?(tests_suite)
        complete_info[tests_suite][test_name] = test_info
      end
      update_tests_info(complete_info)
      discovered_tests.keys
    end

    # Get test statuses for a given tests suite
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite
    # Result::
    # * Array<[String, String]>: Ordered list of couples [test name, test status]
    def statuses_for(tests_suite)
      @tests_suites[tests_suite].statuses
    end

    # Set test statuses for a given tests suite
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite
    # * *statuses* (Array<[String, String]>): Ordered list of couples [test name, test status])
    def set_statuses_for(tests_suite, statuses)
      @tests_suites[tests_suite].statuses = statuses
    end

    # Return test information
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite
    # * *test_name* (String): The test name
    # Result::
    # * Hash<Symbol,Object>: The test information (all properties are optional):
    #   * *name* (String): The test full name
    def test_info(tests_suite, test_name)
      tests_info.dig(tests_suite, test_name) || {}
    end

    # Clear tests for a given tests suite
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite
    def clear_tests_for(tests_suite)
      @tests_suites[tests_suite].clear_tests
    end

    # Run tests in a loop until they are all tested
    #
    # Parameters::
    # * *selected_tests* (Hash<Symbol, Array<String> >): Ordered list of tests to be run, per tests suite
    def run(selected_tests)
      # Test names (ordered) to be performed in game, per tests suite
      # Hash< Symbol, Array<String> >
      in_game_tests = {}
      selected_tests.each do |tests_suite, suite_selected_tests|
        if @tests_suites[tests_suite].respond_to?(:run_test)
          # Simple synchronous tests
          suite_selected_tests.each do |test_name|
            # Store statuses after each test just in case of crash
            set_statuses_for(tests_suite, [[test_name, @tests_suites[tests_suite].run_test(test_name)]])
          end
        end
        # We run the tests from the game itself.
        in_game_tests[tests_suite] = suite_selected_tests if @tests_suites[tests_suite].respond_to?(:in_game_tests_for)
      end
      return if in_game_tests.empty?

      # Keep track of the mapping between tests suites and in-game tests, per in-game tests suite.
      # Associated info is:
      # * *tests_suite* (Symbol): The tests suite that has subscribed to the statuses of some in-game tests of the in-game tests suite.
      # * *in_game_tests* (Array<String>): List of in-game tests that the tests suite is interested in.
      # * *selected_tests* (Array<String>): List of selected tests for which in-game tests are useful.
      # Hash< Symbol, Array< Hash< Symbol, Object > > >
      in_game_tests_subscriptions = {}
      # List of all in-game tests to perform, per in-game tests suite
      # Hash< Symbol, Array< String > >
      merged_in_game_tests = {}
      # Get the list of in-game tests we have to run and that we will monitor
      in_game_tests.each do |tests_suite, suite_selected_tests|
        in_game_tests_to_subscribe = @tests_suites[tests_suite].in_game_tests_for(suite_selected_tests)
        in_game_tests_to_subscribe.each do |in_game_tests_suite, selected_in_game_tests|
          selected_in_game_tests_downcase = selected_in_game_tests.map(&:downcase)
          in_game_tests_subscriptions[in_game_tests_suite] = [] unless in_game_tests_subscriptions.key?(in_game_tests_suite)
          in_game_tests_subscriptions[in_game_tests_suite] << {
            tests_suite: tests_suite,
            in_game_tests: selected_in_game_tests_downcase,
            selected_tests: suite_selected_tests
          }
          merged_in_game_tests[in_game_tests_suite] = [] unless merged_in_game_tests.key?(in_game_tests_suite)
          merged_in_game_tests[in_game_tests_suite] = (merged_in_game_tests[in_game_tests_suite] + selected_in_game_tests_downcase).uniq
        end
      end
      in_game_tests_runner = InGameTestsRunner.new(@config, @game)
      in_game_tests_runner.run(merged_in_game_tests) do |in_game_tests_suite, in_game_tests_statuses|
        # This is a callback called for each in-game test status change.
        # Update the tests results based on what has been run in-game.
        # Find all tests suites that are subscribed to those in-game tests.
        # Be careful that updates can be given for in-game tests suites we were not expecting
        if in_game_tests_subscriptions.key?(in_game_tests_suite)
          in_game_tests_subscriptions[in_game_tests_suite].each do |tests_suite_subscription|
            selected_in_game_tests_statuses = in_game_tests_statuses.slice(*tests_suite_subscription[:in_game_tests])
            next if selected_in_game_tests_statuses.empty?

            tests_suite = @tests_suites[tests_suite_subscription[:tests_suite]]
            tests_suite.statuses = tests_suite.
              parse_auto_tests_statuses_for(tests_suite_subscription[:selected_tests], { in_game_tests_suite => selected_in_game_tests_statuses }).
              select { |(test_name, _test_status)| tests_suite_subscription[:selected_tests].include?(test_name) }
          end
        end
      end
    end

    private

    # Return all tests info.
    # Keep a cache of it.
    #
    # Result::
    # * Hash< Symbol, Hash< String, Hash<Symbol,Object> > >: The tests info, per test name, per tests suite
    def tests_info
      unless defined?(@tests_info_cache)
        @tests_info_cache =
          if File.exist?(@tests_info_file)
            JSON.parse(File.read(@tests_info_file)).map do |tests_suite_str, tests_suite_info|
              [
                tests_suite_str.to_sym,
                tests_suite_info.transform_values { |test_info| test_info.transform_keys(&:to_sym) }
              ]
            end.to_h
          else
            {}
          end
      end
      @tests_info_cache
    end

    # Update tests info.
    #
    # Parameters::
    # * *tests_info* (Hash< Symbol, Hash< String, Hash<Symbol,Object> > >): The tests info, per test name, per tests suite
    def update_tests_info(tests_info)
      # Persist the tests information on disk
      FileUtils.mkdir_p File.dirname(@tests_info_file)
      File.write(@tests_info_file, JSON.pretty_generate(tests_info))
      @tests_info_cache = tests_info
    end

  end

end
