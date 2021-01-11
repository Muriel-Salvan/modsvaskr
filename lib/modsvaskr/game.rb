require 'yaml'
require 'modsvaskr/logger'
require 'modsvaskr/run_cmd'

module Modsvaskr

  # Common functionality for any Game
  class Game

    include Logger, RunCmd

    # Constructor
    #
    # Parameters::
    # * *config* (Config): The config
    # * *game_info* (Hash<String,Object>): Game info:
    #   * *name* (String): Game name
    #   * *path* (String): Game installation dir
    #   * *launch_exe* (String): Executable to be launched
    #   * *min_launch_time_secs* (Integer): Minimum expected lauch time for the game, in seconds [default: 10]
    #   * *tests_poll_secs* (Integer): Interval in seconds to be respected between 2 test statuses polling [default: 5]
    #   * *timeout_frozen_tests_secs* (Integer): Timeout in seconds of a frozen game [default: 300]
    #   * *timeout_interrupt_tests_secs* (Integer): Timeout in seconds for the player to interrupt a tests session before restarting the game [default: 10]
    def initialize(config, game_info)
      @config = config
      # Set default values here
      @game_info = {
        'min_launch_time_secs' => 10,
        'tests_poll_secs' => 5,
        'timeout_frozen_tests_secs' => 300,
        'timeout_interrupt_tests_secs' => 10
      }.merge(game_info)
      @name = name
      init if self.respond_to?(:init)
    end

    # Return the game name
    #
    # Result::
    # * String: Game name
    def name
      @game_info['name']
    end

    # Return the game path
    #
    # Result::
    # * String: Game path
    def path
      @game_info['path']
    end

    # Return the launch executable
    #
    # Result::
    # * String: Launch executable
    def launch_exe
      @game_info['launch_exe']
    end

    # Return the tests polling interval
    #
    # Result::
    # * Integer: Tests polling interval
    def tests_poll_secs
      @game_info['tests_poll_secs']
    end

    # Return the timeout to detect a frozen game
    #
    # Result::
    # * Integer: Timeout to detect a frozen game
    def timeout_frozen_tests_secs
      @game_info['timeout_frozen_tests_secs']
    end

    # Return the timeout before restarting a game tests session
    #
    # Result::
    # * Integer: Timeout before restarting a game tests session
    def timeout_interrupt_tests_secs
      @game_info['timeout_interrupt_tests_secs']
    end

    # Return an xEdit instance for this game
    #
    # Result::
    # * Xedit: The xEdit instance
    def xedit
      @xedit = Xedit.new(@config.xedit_path, path) unless defined?(@xedit)
      @xedit
    end

  end

end
