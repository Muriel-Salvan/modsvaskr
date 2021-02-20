require 'modsvaskr/in_game_tests_suite'

module Modsvaskr

  module TestsSuites

    class ExteriorCell < TestsSuite

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
        # List of exterior cells coordinates, per worldspace name, per plugin name
        # Hash< String, Hash< String, Array<[Integer, Integer]> > >
        exterior_cells = {}
        @game.xedit.run_script('DumpInfo', only_once: true)
        @game.xedit.parse_csv('Modsvaskr_ExportedDumpInfo') do |row|
          esp_name, record_type = row[0..1]
          if record_type.downcase == 'cell'
            cell_type, cell_name, cell_x, cell_y = row[3..6]
            if cell_type == 'cow'
              if cell_x.nil?
                log "!!! Invalid record: #{row}"
              else
                esp_name.downcase!
                exterior_cells[esp_name] = {} unless exterior_cells.key?(esp_name)
                exterior_cells[esp_name][cell_name] = [] unless exterior_cells[esp_name].key?(cell_name)
                exterior_cells[esp_name][cell_name] << [Integer(cell_x), Integer(cell_y)]
              end
            end
          end
        end
        # Test only exterior cells that have been changed by mods, and make sure we test the minimum, knowing that each cell loaded in game tests 5x5 cells around
        vanilla_esps = @game.game_esps
        vanilla_exterior_cells = vanilla_esps.inject({}) do |merged_worldspaces, esp_name|
          merged_worldspaces.merge(exterior_cells[esp_name]) do |worldspace, ext_cells1, ext_cells2|
            (ext_cells1 + ext_cells2).sort.uniq
          end
        end
        changed_exterior_cells = {}
        exterior_cells.each do |esp_name, esp_exterior_cells|
          unless vanilla_esps.include?(esp_name)
            esp_exterior_cells.each do |worldspace, worldspace_exterior_cells|
              if vanilla_exterior_cells.key?(worldspace)
                changed_exterior_cells[worldspace] = [] unless changed_exterior_cells.key?(worldspace)
                changed_exterior_cells[worldspace].concat(vanilla_exterior_cells[worldspace] & worldspace_exterior_cells)
              end
            end
          end
        end
        tests = {}
        # Value taken from the ini file
        # TODO: Read it from there (uiGrid)
        loaded_grid = 5
        delta_cells = loaded_grid / 2
        changed_exterior_cells.each do |worldspace, worldspace_exterior_cells|
          # Make sure we select the minimum cells
          # Use a Hash of Hashes for the coordinates to speed-up their lookup.
          remaining_cells = {}
          worldspace_exterior_cells.each do |(cell_x, cell_y)|
            remaining_cells[cell_x] = {} unless remaining_cells.key?(cell_x)
            remaining_cells[cell_x][cell_y] = nil
          end
          while !remaining_cells.empty?
            cell_x, cell_ys = remaining_cells.first
            cell_y, _nil = cell_ys.first
            # We want to test cell_x, cell_y.
            # Knowing that we can test it by loading any cell in the range ((cell_x - delta_cells..cell_x + delta_cells), (cell_y - delta_cells..cell_y + delta_cells)),
            # check which cell would test the most wanted cells from our list
            best_cell_x, best_cell_y, best_cell_score = nil, nil, nil
            (cell_x - delta_cells..cell_x + delta_cells).each do |candidate_cell_x|
              (cell_y - delta_cells..cell_y + delta_cells).each do |candidate_cell_y|
                # Check the number of cells that would be tested if we were to test (candidate_cell_x, candidate_cell_y)
                nbr_tested_cells = remaining_cells.
                  slice(*(candidate_cell_x - delta_cells..candidate_cell_x + delta_cells)).
                  inject(0) { |sum_cells, (_cur_cell_x, cur_cell_ys)| sum_cells + cur_cell_ys.slice(*(candidate_cell_y - delta_cells..candidate_cell_y + delta_cells)).size }
                if best_cell_score.nil? || nbr_tested_cells > best_cell_score
                  nbr_tested_cells = best_cell_score
                  best_cell_x = candidate_cell_x
                  best_cell_y = candidate_cell_y
                end
              end
            end
            # Remove the tested cells from the remaining ones
            (best_cell_x - delta_cells..best_cell_x + delta_cells).each do |cur_cell_x|
              if remaining_cells.key?(cur_cell_x)
                (best_cell_y - delta_cells..best_cell_y + delta_cells).each do |cur_cell_y|
                  remaining_cells[cur_cell_x].delete(cur_cell_y)
                end
                remaining_cells.delete(cur_cell_x) if remaining_cells[cur_cell_x].empty?
              end
            end
            tests["#{worldspace}/#{best_cell_x}/#{best_cell_y}"] = {
              name: "Load #{worldspace} cell #{best_cell_x}, #{best_cell_y}"
            }
          end
        end
        tests
      end

    end

  end

end
