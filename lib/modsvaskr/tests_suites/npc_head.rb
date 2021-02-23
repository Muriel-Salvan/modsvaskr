require 'modsvaskr/in_game_tests_suite'

module Modsvaskr

  module TestsSuites

    class NpcHead < TestsSuite

      include InGameTestsSuite

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
        tests = {}
        @game.xedit.run_script('DumpInfo', only_once: true)
        @game.xedit.parse_csv('Modsvaskr_ExportedDumpInfo') do |row|
          if row[1].downcase == 'npc_'
            # Know from which mod this ID comes from
            plugin, base_form_id = @game.decode_form_id(row[2])
            test_name = "#{plugin}/#{base_form_id}"
            if tests.key?(test_name)
              # Add the name of the mod to the description, so that we know which mod modifies which NPC.
              tests[test_name][:name] << "/#{row[0].downcase}"
            else
              tests[test_name] = {
                name: "Take head screenshot of #{row[3]} - #{row[0].downcase}"
              }
            end
          end
        end
        tests
      end

    end

  end

end
