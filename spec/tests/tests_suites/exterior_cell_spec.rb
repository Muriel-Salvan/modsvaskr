describe 'Game tests menu' do

  context 'when checking tests suite plugin' do

    describe 'exterior_cell' do

      let(:tests_suite) { :exterior_cell }

      it 'discovers 1 test' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
            "mod1.esp",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
          EO_CSV
        )
        expect_menu_items_to_include('[+] exterior_cell - 0 / 1')
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-2/-2 -  - Load LabyrinthianMazeWorld cell -2, -2', menu_idx: -4)
      end

      it 'discovers 1 test having non-ASCI characters' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",CELL,0001AB5F,cow,フォートサンガード,0,0
            "mod1.esp",CELL,0001AB5F,cow,フォートサンガード,0,0
          EO_CSV
        )
        expect_menu_items_to_include('[+] exterior_cell - 0 / 1')
        expect_menu_items_to_include(/\[ \] .+ -  - Load .* cell -2, -2/, menu_idx: -4)
        # TODO: Use the following when ncurses will handle UTF-8 properly
        # expect_menu_items_to_include('[ ] フォートサンガード -  - Load フォートサンガード cell -2, -2', menu_idx: -4)
      end

      it 'discovers only cells modifying the vanilla ones' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",CELL,0001AB52,cow,LabyrinthianMazeWorld01,0,0
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld02,0,0
            "test_game.esm",CELL,0001AB54,cow,LabyrinthianMazeWorld03,0,0
            "test_game.esm",CELL,0001AB55,cow,LabyrinthianMazeWorld04,0,0
            "mod1.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld02,0,0
            "mod2.esp",CELL,0001AB55,cow,LabyrinthianMazeWorld04,0,0
          EO_CSV
        )
        expect_menu_items_to_include('[+] exterior_cell - 0 / 2')
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld02/-2/-2 -  - Load LabyrinthianMazeWorld02 cell -2, -2', menu_idx: -4)
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld04/-2/-2 -  - Load LabyrinthianMazeWorld04 cell -2, -2', menu_idx: -4)
      end

      it 'ignores other data dump when discovering tests' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",CELL,0001AB5F,coc,FortSungard03
            "test_game.esm",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
            "test_game.esm",NPC_,00014137,Angrenor Once-Honored
            "mod1.esp",NPC_,00014137,Angrenor Once-Honored
            "mod1.esp",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
            "mod1.esp",CELL,0001AB5F,coc,FortSungard03
          EO_CSV
        )
        expect_menu_items_to_include('[+] exterior_cell - 0 / 1')
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-2/-2 -  - Load LabyrinthianMazeWorld cell -2, -2', menu_idx: -4)
      end

      it 'groups 2 cells that are in the same grid' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",CELL,0001AB52,cow,LabyrinthianMazeWorld,0,0
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,1,1
            "mod1.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,0,0
            "mod2.esp",CELL,0001AB55,cow,LabyrinthianMazeWorld,1,1
          EO_CSV
        )
        expect_menu_items_to_include('[+] exterior_cell - 0 / 1')
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-1/-1 -  - Load LabyrinthianMazeWorld cell -1, -1', menu_idx: -4)
      end

      it 'groups several cells so that only 1 test is done for each grid' do
        # Here are the cells to be tested
        # Legend:
        # * - Cell modified by a mod
        # X - Cell to be tested
        # +/-/| - Frontier of all cells being tested by one of the cell marked to be tested (5x5 grid around)
        #     -10 -09 -08 -07 -06 -05 -04 -03 -02 -01  00  01  02  03  04  05  06  07  08  09  10
        #                +-------------------+
        # -10            |     *             |
        #                |                   |
        # -09            |                   |
        #                |                   |
        # -08            |         X         |
        #                |                   |
        # -07            |                 * |
        #    +-------------------+           |
        # -06|           |       |     *     |
        #    |           +-------|-----------+
        # -05|                 * |
        #    |                   |                   +-------------------+
        # -04|         X         |                   |                   |
        #    |                   |                   |                   |
        # -03|                   |                   |                   |
        #    |                   |                   |                   |
        # -02|                 * |                   |         *X        |
        #    +-------------------+                   |                   |
        # -01                                        |                   |
        #                                            |                   |
        #  00                                        |                 * |
        #                                            +-------------------+
        #  01
        #                    +-------------------+
        #  02                |                   |
        #                    |                   |
        #  03                |                   |
        #                    |                   |
        #  04                |         X         |
        #                    |                   |
        #  05                |                   |
        #                    |                   |
        #  06                | *           *   * |
        #                    +-------------------+
        #  07
        #
        #  08
        #
        #  09
        #
        #  10
        #
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",CELL,0001AB52,cow,LabyrinthianMazeWorld,-10,-6
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,-7,-3
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,-6,-4
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,-5,-6
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,-2,-6
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,-2,2
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,0,4
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,6,-6
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,6,-3
            "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,6,-2
            "mod1.esp",CELL,0001AB52,cow,LabyrinthianMazeWorld,-10,-6
            "mod2.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,-7,-3
            "mod1.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,-6,-4
            "mod2.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,-5,-6
            "mod1.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,-2,-6
            "mod2.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,-2,2
            "mod1.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,0,4
            "mod2.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,6,-6
            "mod1.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,6,-3
            "mod2.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,6,-2
          EO_CSV
        )
        expect_menu_items_to_include('[+] exterior_cell - 0 / 4')
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-8/-5 -  - Load LabyrinthianMazeWorld cell -8, -5', menu_idx: -4)
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-4/-8 -  - Load LabyrinthianMazeWorld cell -4, -8', menu_idx: -4)
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-2/2 -  - Load LabyrinthianMazeWorld cell -2, 2', menu_idx: -4)
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/4/-4 -  - Load LabyrinthianMazeWorld cell 4, -4', menu_idx: -4)
      end

      it 'runs in-game tests Locations' do
        run_and_discover(
          run: true,
          expect_tests: {
            locations: %w[labyrinthianmazeworld/-2/-2]
          },
          mock_tests_statuses: {
            locations: {
              'labyrinthianmazeworld/-2/-2' => 'ok'
            }
          },
          csv: <<~EO_CSV
            "test_game.esm",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
            "mod1.esp",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
          EO_CSV
        )
        expect_menu_items_to_include('[*] exterior_cell - 1 / 1')
      end

    end

  end

end
