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
    def initialize(config, game_info)
      @config = config
      @game_info = game_info
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
