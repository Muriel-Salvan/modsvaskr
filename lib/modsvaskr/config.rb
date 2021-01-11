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
      @config = YAML.load(File.read(file)) || {}
      # Parse all game types plugins
      # Hash<Symbol, Class>
      @game_types = Hash[
        Dir.glob("#{__dir__}/games/*.rb").map do |game_type_file|
          require game_type_file
          base_name = File.basename(game_type_file, '.rb')
          [
            base_name.to_sym,
            Games.const_get(base_name.split('_').collect(&:capitalize).join.to_sym)
          ]
        end
      ]
    end

    # Get the games list
    #
    # Result::
    # * Array<Game>: List of games
    def games
      unless defined?(@games)
        @games = (@config['games'] || []).map do |game_info|
          game_type = game_info['type'].to_sym
          raise "Unknown game type: #{game_type}. Available ones are #{@game_types.keys.join(', ')}" unless @game_types.key?(game_type)
          @game_types[game_type].new(self, game_info)
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
