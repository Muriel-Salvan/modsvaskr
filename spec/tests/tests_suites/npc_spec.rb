describe 'Game tests menu' do

  context 'checking tests suite plugin' do

    context 'npc' do

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
        set_test_tests_suites([:npc])
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
          "test_game.esm",NPC_,00014137,Angrenor Once-Honored
          "test_game.esm",TES4,
        EO_CSV
        expect_menu_items_to_include('[+] npc - 0 / 1')
        expect_menu_items_to_include('[ ] test_game.esm/82231 -  - Take screenshot of Angrenor Once-Honored - test_game.esm', menu_idx: -4)
      end

      it 'discovers 1 test having non-ASCI characters' do
        discover_with <<~EO_CSV
          "test_game.esm",NPC_,00014137,フォートサンガード
          "test_game.esm",TES4,
        EO_CSV
        expect_menu_items_to_include('[+] npc - 0 / 1')
        expect_menu_items_to_include(/\[ \] test_game.esm\/82231 -  - Take screenshot of .+ - test_game.esm/, menu_idx: -4)
        # TODO: Use the following when ncurses will handle UTF-8 properly
        # expect_menu_items_to_include('[ ] test_game.esm/82231 -  - Take screenshot of フォートサンガード - test_game.esm', menu_idx: -4)
      end

      it 'discovers 1 test per NPC even when mods modify the same NPC' do
        discover_with <<~EO_CSV
          "test_game.esm",NPC_,00014131,Angrenor1
          "test_game.esm",NPC_,00014132,Angrenor2
          "test_game.esm",TES4,
          "mod1.esp",NPC_,00014131,Angrenor1
          "mod1.esp",TES4,,test_game.esm
          "mod2.esp",NPC_,00014131,Angrenor1
          "mod2.esp",NPC_,00014132,Angrenor2
          "mod2.esp",TES4,,test_game.esm
          "mod3.esp",NPC_,01014133,Angrenor3
          "mod3.esp",TES4,,test_game.esm
          "mod4.esp",NPC_,02014133,Angrenor3
          "mod4.esp",TES4,,test_game.esm,mod1.esp,mod3.esp
        EO_CSV
        expect_menu_items_to_include('[+] npc - 0 / 3')
        expect_menu_items_to_include('[ ] test_game.esm/82225 -  - Take screenshot of Angrenor1 - test_game.esm/mod1.esp/mod2.esp', menu_idx: -4)
        expect_menu_items_to_include('[ ] test_game.esm/82226 -  - Take screenshot of Angrenor2 - test_game.esm/mod2.esp', menu_idx: -4)
        expect_menu_items_to_include('[ ] mod3.esp/82227 -  - Take screenshot of Angrenor3 - mod3.esp/mod4.esp', menu_idx: -4)
      end

      it 'ignores other data dump when discovering tests' do
        discover_with <<~EO_CSV
          "test_game.esm",CELL,0001AB5F,coc,FortSungard03
          "test_game.esm",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
          "test_game.esm",NPC_,00014137,Angrenor Once-Honored
          "test_game.esm",TES4,
          "mod1.esp",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
          "mod1.esp",CELL,0001AB5F,coc,FortSungard03
          "mod1.esp",TES4,,test_game.esm
        EO_CSV
        expect_menu_items_to_include('[+] npc - 0 / 1')
        expect_menu_items_to_include('[ ] test_game.esm/82231 -  - Take screenshot of Angrenor Once-Honored - test_game.esm', menu_idx: -4)
      end

      it 'fails when masters could not be parsed' do
        expect do
          discover_with <<~EO_CSV
            "test_game.esm",NPC_,00014137,Angrenor Once-Honored
          EO_CSV
        end.to raise_error 'Esp test_game.esm declares NPC FormID 82231 (Angrenor Once-Honored) but its masters could not be parsed'
      end

      it 'fails when masters are parsed incorrectly' do
        expect do
          discover_with <<~EO_CSV
            "test_game.esm",TES4,
            "mod1.esp",TES4,,test_game.esm
            "mod2.esp",TES4,,test_game.esm
            "mod3.esp",NPC_,04014133,Angrenor3
            "mod3.esp",TES4,,test_game.esm,mod1.esp,mod2.esp
          EO_CSV
        end.to raise_error 'NPC FormID 67191091 (Angrenor3) from mod3.esp references an unknown master (known masters: test_game.esm, mod1.esp, mod2.esp)'
      end

      it 'runs in-game tests NPCs' do
        mock_xedit_dump_with <<~EO_CSV
          "test_game.esm",NPC_,00014137,Angrenor Once-Honored
          "test_game.esm",TES4,
        EO_CSV
        mock_in_game_tests_run(
          expect_tests: {
            npcs: %w[test_game.esm/82231]
          },
          mock_tests_statuses: {
            npcs: {
              'test_game.esm/82231' => 'ok'
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
        expect_menu_items_to_include('[*] npc - 1 / 1')
      end

    end

  end

end
