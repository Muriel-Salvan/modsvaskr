module Modsvaskr

  module TestsSuites

    class InteriorCell < TestsSuite

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
        CSV.read("#{@game.xedit.install_path}/Edit Scripts/Modsvaskr_ExportedDumpInfo.csv", encoding: 'windows-1251:utf-8').each do |row|
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
        vanilla_interior_cells = vanilla_esps.map { |esp_name| interior_cells[esp_name] }.flatten.sort.uniq
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

      # Get the list of tests to be run in-game for a given list of test names.
      # [API] - This method is mandatory for tests needing to be run in-game.
      #
      # Parameters::
      # * *tests* (Array<String>): List of test names
      # Result::
      # * Hash<Symbol, Array<String> >: List of in-game test names, per in-game tests suite
      def in_game_tests_for(tests)
        { locations: tests }
      end

      # Set statuses based on the result of AutoTest statuses.
      # AutoTest names are case insensitive.
      # [API] - This method is mandatory for tests needing to be run in-game.
      #
      # Parameters::
      # * *tests* (Array<String>): List of test names
      # * *auto_test_statuses* (Hash<Symbol, Array<[String, String]> >): Ordered list of AutoTest [test name, test status], per AutoTest tests suite
      # Result::
      # * Array<[String, String]>: Corresponding list of [test name, test status]
      def parse_auto_tests_statuses_for(tests, auto_test_statuses)
        auto_test_statuses.key?(:locations) ? auto_test_statuses[:locations] : []
      end

    end

  end

end
