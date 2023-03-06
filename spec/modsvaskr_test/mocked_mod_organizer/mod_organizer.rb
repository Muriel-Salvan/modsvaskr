require 'modsvaskr_test/mocked_mod_organizer/mod'

module ModsvaskrTest

  module MockedModOrganizer

    class ModOrganizer

      attr_reader :run_called, :mods_list

      # Constructor
      #
      # Parameters::
      # * *mods* (Hash<String, Hash<Symbol,Object>>): List of mods to mock, per mod name [default: {}]
      #   * *enabled* (Boolean): Is the mod enabled? [default: true]
      #   * *categories* (Array<String>): List of this mod's categories [default: []]
      #   * *plugins* (Array<String>): List of this mod's plugins [default: []]
      #   * *sources* (Array< Hash<Symbol,Object> >): List of this mod's sources [default: []]
      # * *mods_list* (Array<String>): The ordered list of mod names [default: mods.keys]
      # * *categories* (Hash<Integer, String>): Categories to return, or nil for default (built from mods' categories) [default: nil]
      def initialize(
        mods: {},
        mods_list: mods.keys
      )
        @mods = mods
        @mods_list = mods_list
        @run_called = false
      end

      # Return mod_names
      #
      # Result::
      # * Array<String>: Mod names
      def mod_names
        @mods.keys
      end

      # Return a mod of a given name
      #
      # Parameters::
      # * *name* (String): Mod namd
      # Result::
      # * MockedMod: The mocked mod
      def mod(name:)
        Mod.new(**@mods[name])
      end

      # Run ModOrganizer
      def run
        @run_called = true
      end

    end

  end

end
