require 'modsvaskr/tests_suites/npc'

module Modsvaskr

  module TestsSuites

    class NpcHead < TestsSuites::Npc

      # Return the in-game tests suite to which we forward the tests to be run
      #
      # Result::
      # * Symbol: In-game tests suite
      def in_game_tests_suite
        :npcshead
      end

      # Discover the list of tests information that could be run.
      # [API] - This method is mandatory
      #
      # Result::
      # * Hash< String, Hash<Symbol,Object> >: Ordered hash of test information, per test name
      def discover_tests
        tests = super
        tests.values.each do |test_info|
          test_info[:name].gsub!('Take screenshot', 'Take head screenshot')
        end
        tests
      end

    end

  end

end
