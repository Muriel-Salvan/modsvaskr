require 'mod_organizer'
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
      @config = YAML.safe_load(File.read(file)) || {}
      # Parse all game types plugins
      # Hash<Symbol, Class>
      @game_types = Dir.glob("#{__dir__}/games/*.rb").to_h do |game_type_file|
        require game_type_file
        base_name = File.basename(game_type_file, '.rb')
        [
          base_name.to_sym,
          Games.const_get(base_name.split('_').collect(&:capitalize).join.to_sym)
        ]
      end
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

    # Return the 7-Zip path
    #
    # Result::
    # * String: The 7-Zip path
    def seven_zip_path
      @config['7zip']
    end

    # Return the automated keys to apply
    #
    # Result::
    # * Array<String>: The list of automated keys
    def auto_keys
      @config['auto_keys'] || []
    end

    # Return the no_prompt flag
    #
    # Result::
    # * Boolean: no_prompt flag
    def no_prompt
      @config['no_prompt'] || false
    end

    # Return the ModOrganizer instance, if configured.
    #
    # Result::
    # * ModOrganizer or nil: The ModOrganizer instance, or nil if none
    def mod_organizer
      return nil unless @config['mod_organizer']

      ModOrganizer.new(
        @config['mod_organizer']['installation_dir'],
        instance_name: @config['mod_organizer']['instance_name']
      )
    end

  end

end
