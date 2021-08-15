describe 'Game tests menu' do

  context 'checking tests suite plugin' do

    context 'exterior_cell' do

      around(:each) do |example|
        # Register the key sequence getting to the desired menu
        entering_menu_keys %w[KEY_ENTER KEY_ENTER]
        exiting_menu_keys %w[KEY_ESCAPE KEY_ESCAPE]
        menu_index_to_test -3
        with_tmp_dir('test_game') do |game_dir|
          @game_dir = game_dir
          with_tmp_dir('xedit') do |xedit_dir|
            @xedit_dir = xedit_dir
            FileUtils.mkdir_p("#{xedit_dir}/Edit Scripts")
            @config = {
              'games' => [
                {
                  'name' => 'Test Game',
                  'path' => game_dir,
                  'type' => 'test_game',
                  'launch_exe' => 'game_launcher.exe',
                  'min_launch_time_secs' => 1,
                  'tests_poll_secs' => 1,
                  'timeout_frozen_tests_secs' => 300
                }
              ],
              'xedit' => xedit_dir
            }
            example.run
          end
        end
      end

      before(:each) do
        set_test_tests_suites([:exterior_cell])
      end

      # Run commands to discover tests with a given mocked CSV from xEdit
      #
      # Parameters::
      # * *csv* (String): The CSV to be mocked
      def discover_with(csv)
        mock_xedit_dump_with csv
        run_modsvaskr(
          config: @config,
          keys: %w[KEY_ENTER KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check the list of tests
            %w[KEY_HOME d KEY_ESCAPE]
        )
      end

      it 'discovers 1 test' do
        discover_with <<~EO_CSV
          "test_game.esm",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
          "mod1.esp",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
        EO_CSV
        expect_menu_items_to_include('[+] exterior_cell - 0 / 1')
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-2/-2 -  - Load LabyrinthianMazeWorld cell -2, -2', menu_idx: -4)
      end

      it 'discovers 1 test having non-ASCI characters' do
        discover_with <<~EO_CSV
          "test_game.esm",CELL,0001AB5F,cow,フォートサンガード,0,0
          "mod1.esp",CELL,0001AB5F,cow,フォートサンガード,0,0
        EO_CSV
        expect_menu_items_to_include('[+] exterior_cell - 0 / 1')
        expect_menu_items_to_include(/\[ \] .+ -  - Load .* cell -2, -2/, menu_idx: -4)
        # TODO: Use the following when ncurses will handle UTF-8 properly
        # expect_menu_items_to_include('[ ] フォートサンガード -  - Load フォートサンガード cell -2, -2', menu_idx: -4)
      end

      it 'discovers only cells modifying the vanilla ones' do
        discover_with <<~EO_CSV
          "test_game.esm",CELL,0001AB52,cow,LabyrinthianMazeWorld01,0,0
          "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld02,0,0
          "test_game.esm",CELL,0001AB54,cow,LabyrinthianMazeWorld03,0,0
          "test_game.esm",CELL,0001AB55,cow,LabyrinthianMazeWorld04,0,0
          "mod1.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld02,0,0
          "mod2.esp",CELL,0001AB55,cow,LabyrinthianMazeWorld04,0,0
        EO_CSV
        expect_menu_items_to_include('[+] exterior_cell - 0 / 2')
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld02/-2/-2 -  - Load LabyrinthianMazeWorld02 cell -2, -2', menu_idx: -4)
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld04/-2/-2 -  - Load LabyrinthianMazeWorld04 cell -2, -2', menu_idx: -4)
      end

      it 'ignores other data dump when discovering tests' do
        discover_with <<~EO_CSV
          "test_game.esm",CELL,0001AB5F,coc,FortSungard03
          "test_game.esm",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
          "test_game.esm",NPC_,00014137,Angrenor Once-Honored
          "mod1.esp",NPC_,00014137,Angrenor Once-Honored
          "mod1.esp",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
          "mod1.esp",CELL,0001AB5F,coc,FortSungard03
        EO_CSV
        expect_menu_items_to_include('[+] exterior_cell - 0 / 1')
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-2/-2 -  - Load LabyrinthianMazeWorld cell -2, -2', menu_idx: -4)
      end

      it 'groups 2 cells that are in the same grid' do
        discover_with <<~EO_CSV
          "test_game.esm",CELL,0001AB52,cow,LabyrinthianMazeWorld,0,0
          "test_game.esm",CELL,0001AB53,cow,LabyrinthianMazeWorld,1,1
          "mod1.esp",CELL,0001AB53,cow,LabyrinthianMazeWorld,0,0
          "mod2.esp",CELL,0001AB55,cow,LabyrinthianMazeWorld,1,1
        EO_CSV
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
        discover_with <<~EO_CSV
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
        expect_menu_items_to_include('[+] exterior_cell - 0 / 4')
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-8/-5 -  - Load LabyrinthianMazeWorld cell -8, -5', menu_idx: -4)
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-4/-8 -  - Load LabyrinthianMazeWorld cell -4, -8', menu_idx: -4)
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/-2/2 -  - Load LabyrinthianMazeWorld cell -2, 2', menu_idx: -4)
        expect_menu_items_to_include('[ ] LabyrinthianMazeWorld/4/-4 -  - Load LabyrinthianMazeWorld cell 4, -4', menu_idx: -4)
      end

      it 'runs in-game tests Locations' do
        mock_xedit_dump_with <<~EO_CSV
          "test_game.esm",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
          "mod1.esp",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
        EO_CSV
        mock_in_game_tests_run(
          expect_tests: {
            locations: %w[labyrinthianmazeworld/-2/-2]
          },
          mock_tests_statuses: {
            locations: {
              'labyrinthianmazeworld/-2/-2' => 'ok'
            }
          }
        )
        run_modsvaskr(
          config: @config,
          keys: %w[KEY_ENTER KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Select all tests
            %w[KEY_HOME KEY_ENTER] +
            # Run the tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER]
        )
        expect_menu_items_to_include('[*] exterior_cell - 1 / 1')
      end

    end

  end

end
