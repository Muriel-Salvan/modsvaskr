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
        # Keep track of masters, per plugin
        # Hash<String, Array<String> >
        masters = {}
        # Keep track of NPCs
        # Array< [String, Integer, String] >
        # Array< [Plugin, FormID,  NPC   ] >
        npcs = []
        @game.xedit.parse_csv('Modsvaskr_ExportedDumpInfo') do |row|
          case row[1].downcase
          when 'npc_'
            npcs << [row[0].downcase, row[2].to_i(16), row[3]]
          when 'tes4'
            masters[row[0].downcase] = row[3..-1].map(&:downcase)
          end
        end
        npcs.each do |(esp, form_id, npc_name)|
          raise "Esp #{esp} declares NPC FormID #{form_id} (#{npc_name}) but its masters could not be parsed" unless masters.key?(esp)
          # Know from which mod this ID comes from
          mod_idx = form_id / 16_777_216
          raise "NPC FormID #{form_id} (#{npc_name}) from #{esp} references an unknown master (known masters: #{masters[esp].join(', ')})" if mod_idx > masters[esp].size
          test_name = "#{mod_idx == masters[esp].size ? esp : masters[esp][mod_idx]}/#{form_id % 16_777_216}"
          if tests.key?(test_name)
            # Add the name of the mod to the description, so that we know which mod modifies which NPC.
            tests[test_name][:name] << "/#{esp}"
          else
            tests[test_name] = {
              name: "Take screenshot of #{npc_name} - #{esp}"
            }
          end
        end
        tests
      end

    end

  end

end
