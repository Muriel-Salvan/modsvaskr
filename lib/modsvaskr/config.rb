require 'yaml'
require 'modsvaskr/game'
require 'modsvaskr/xedit'

module Modsvaskr

  # Configuration
  class Config

    # Constructor
    #
    # Parameters::
    # * *file* (String): File containing configuration
    def initialize(file)
      @config = YAML.load(File.read(file))
    end

    # Get the games list
    #
    # Result::
    # * Array<Game>: List of games
    def games
      unless defined?(@games)
        @games = @config['games'].map do |game_info|
          require "#{__dir__}/games/#{game_info['type']}.rb"
          Games.const_get(game_info['type'].to_s.split('_').collect(&:capitalize).join.to_sym).new(self, game_info)
        end
      end
      @games
    end

    # Return the xEdit path
    #
    # Result::
    # * String: The xEdit path
    def xedit_path
      @config['xedit']
    end

  end

end
