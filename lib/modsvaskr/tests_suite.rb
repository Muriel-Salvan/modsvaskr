require 'fileutils'
require 'json'
require 'modsvaskr/logger'
require 'modsvaskr/run_cmd'

module Modsvaskr

  # Common functionality for any tests suite
  class TestsSuite

    include Logger, RunCmd

    # Constructor
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite name
    # * *game* (Game): The game for which this test type is instantiated
    def initialize(tests_suite, game)
      @tests_suite = tests_suite
      @game = game
    end

    # Get test statuses
    #
    # Result::
    # * Array<[String, String]>: Ordered list of [test name, test status]
    def statuses
      File.exist?(json_statuses_file) ? JSON.parse(File.read(json_statuses_file)) : []
    end

    # Set test statuses.
    # Add new ones and overwrites existing ones.
    #
    # Parameters::
    # * *statuses* (Array<[String, String]>): Ordered list of [test name, test status]
    def set_statuses(statuses)
      current_statuses = self.statuses
      statuses.each do |(test_name, test_status)|
        test_status_info = current_statuses.find { |(search_test_name, _search_test_status)| search_test_name == test_name }
        if test_status_info.nil?
          # New one. Add it to the end.
          current_statuses << [test_name, test_status]
        else
          # Already existing. Just change its status.
          test_status_info[1] = test_status
        end
      end
      FileUtils.mkdir_p File.dirname(json_statuses_file)
      File.write(json_statuses_file, JSON.pretty_generate(current_statuses))
    end

    # Remove all tests from this suite
    def clear_tests
      File.unlink(json_statuses_file) if File.exist?(json_statuses_file)
    end

    private

    # Get the JSON statuses file name
    #
    # Result::
    # * String: The JSON statuses file name
    def json_statuses_file
      "#{@game.path}/Data/Modsvaskr/Tests/Statuses_#{@tests_suite}.json"
    end

  end

end
