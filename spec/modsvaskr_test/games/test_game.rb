require 'open-uri'
require 'tmpdir'
require 'nokogiri'

module ModsvaskrTest

  module Games

    # Test game plugin
    class TestGame < Modsvaskr::Game

      class << self
        attr_accessor *%i[
          menu_proc
          init_proc
        ]
      end

      # Initialize the game
      # [API] - This method is optional
      def init
        TestGame.init_proc.call unless TestGame.init_proc.nil?
      end

      # Complete the game menu
      # [API] - This method is optional
      #
      # Parameters::
      # * *menu* (CursesMenu): Menu to complete
      def complete_game_menu(menu)
        TestGame.menu_proc.call(menu) unless TestGame.menu_proc.nil?
      end

      # Get the game running executable name (that can be found in a tasks manager)
      # [API] - This method is mandatory
      #
      # Result::
      # * String: The running exe name
      def running_exe
        'TestGame.exe'
      end

      # List of default esps present in the game (the ones in the Data folder when 0 mod is being used)
      #
      # Result::
      # * Array<String>: List of esp/esm/esl base file names.
      def game_esps
        %w[
          test_game.esm
          test_game_update.esm
        ]
      end

    end

  end

end
