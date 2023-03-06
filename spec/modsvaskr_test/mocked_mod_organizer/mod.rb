require 'modsvaskr_test/mocked_mod_organizer/source'

module ModsvaskrTest

  module MockedModOrganizer

    class Mod

      attr_reader :categories, :plugins, :url

      # Constructor
      #
      # Parameters::
      # * *enabled* (Boolean): Is the mod enabled? [default: true]
      # * *categories* (Array<String>): List of this mod's categories [default: []]
      # * *plugins* (Array<String>): List of this mod's plugins [default: []]
      # * *sources* (Array< Hash<Symbol,Object> >): List of this mod's sources [default: []]
      # * *url* (String): This mod's URL [default: 'https://my_test_mod.com']
      def initialize(enabled: true, categories: [], plugins: [], sources: [], url: 'https://my_test_mod.com')
        @enabled = enabled
        @categories = categories
        @plugins = plugins
        @sources = sources
        @url = url
      end

      # Is the mod enabled?
      #
      # Result::
      # * Boolean: Is the mod enabled?
      def enabled?
        @enabled
      end

      # Return the list of sources this mod belongs to
      #
      # Result::
      # * Array<MockedSource>: List of source information
      def sources
        @sources.map { |source| Source.new(**source) }
      end

    end

  end

end
