require 'modsvaskr/in_game_tests_suite'

module Modsvaskr

  module TestsSuites

    class InteriorCell < TestsSuite

      include InGameTestsSuite

      # Return the in-game tests suite to which we forward the tests to be run
      #
      # Result::
      # * Symbol: In-game tests suite
      def in_game_tests_suite
        :locations
      end

      # Discover the list of tests information that could be run.
      # [API] - This method is mandatory
      #
      # Result::
      # * Hash< String, Hash<Symbol,Object> >: Ordered hash of test information, per test name
      def discover_tests
        # List of interior cells, per plugin name
        # Hash< String, Array<String> >
        interior_cells = {}
        @game.xedit.run_script('DumpInfo', only_once: true)
        @game.xedit.parse_csv('Modsvaskr_ExportedDumpInfo') do |row|
          esp_name, record_type = row[0..1]
          if record_type.downcase == 'cell'
            cell_type, cell_name = row[3..4]
            if cell_type == 'coc'
              esp_name.downcase!
              interior_cells[esp_name] = [] unless interior_cells.key?(esp_name)
              interior_cells[esp_name] << cell_name
            end
          end
        end
        # Test only interior cells that have been changed by mods
        vanilla_esps = @game.game_esps
        vanilla_interior_cells = vanilla_esps.map { |esp_name| interior_cells[esp_name] || [] }.flatten.sort.uniq
        Hash[interior_cells.
          map { |esp_name, esp_cells| vanilla_esps.include?(esp_name) ? [] : vanilla_interior_cells & esp_cells }.
          flatten.
          sort.
          uniq.
          map do |cell_name|
            [
              cell_name,
              {
                name: "Load cell #{cell_name}"
              }
            ]
          end
        ]
      end

    end

  end

end
