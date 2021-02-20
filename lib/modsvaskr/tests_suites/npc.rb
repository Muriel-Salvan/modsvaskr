require 'modsvaskr/in_game_tests_suite'

module Modsvaskr

  module TestsSuites

    class Npc < TestsSuite

      include InGameTestsSuite

      # Return the in-game tests suite to which we forward the tests to be run
      #
      # Result::
      # * Symbol: In-game tests suite
      def in_game_tests_suite
        :npcs
      end

      # Discover the list of tests information that could be run.
      # [API] - This method is mandatory
      #
      # Result::
      # * Hash< String, Hash<Symbol,Object> >: Ordered hash of test information, per test name
      def discover_tests
        tests = {}
        @game.xedit.run_script('DumpInfo', only_once: true)
        CSV.read("#{@game.xedit.install_path}/Edit Scripts/Modsvaskr_ExportedDumpInfo.csv", encoding: 'windows-1251:utf-8').each do |row|
          tests["#{row[0].downcase}/#{row[2].to_i(16)}"] = {
            name: "Take screenshot of #{row[0]} - #{row[3]}"
          } if row[1].downcase == 'npc_'
        end
        tests
      end

    end

  end

end
