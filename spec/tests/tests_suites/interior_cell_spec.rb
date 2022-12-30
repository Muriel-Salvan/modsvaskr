describe 'Game tests menu' do

  context 'when checking tests suite plugin' do

    describe 'interior_cell' do

      let(:tests_suite) { :interior_cell }

      it 'discovers 1 test' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",CELL,0001AB5F,coc,FortSungard03
            "mod1.esp",CELL,0001AB5F,coc,FortSungard03
          EO_CSV
        )
        expect_menu_items_to_include('[+] interior_cell - 0 / 1')
        expect_menu_items_to_include('[ ] FortSungard03 -  - Load cell FortSungard03', menu_idx: -4)
      end

      it 'discovers 1 test having non-ASCI characters' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",CELL,0001AB5F,coc,フォートサンガード
            "mod1.esp",CELL,0001AB5F,coc,フォートサンガード
          EO_CSV
        )
        expect_menu_items_to_include('[+] interior_cell - 0 / 1')
        expect_menu_items_to_include(/\[ \] .+ -  - Load cell .+/, menu_idx: -4)
        # TODO: Use the following when ncurses will handle UTF-8 properly
        # expect_menu_items_to_include('[ ] フォートサンガード -  - Load cell フォートサンガード', menu_idx: -4)
      end

      it 'discovers only cells modifying the vanilla ones' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",CELL,0001AB52,coc,FortSungard02
            "test_game.esm",CELL,0001AB53,coc,FortSungard03
            "test_game.esm",CELL,0001AB54,coc,FortSungard04
            "test_game.esm",CELL,0001AB55,coc,FortSungard05
            "mod1.esp",CELL,0001AB53,coc,FortSungard03
            "mod2.esp",CELL,0001AB55,coc,FortSungard05
          EO_CSV
        )
        expect_menu_items_to_include('[+] interior_cell - 0 / 2')
        expect_menu_items_to_include('[ ] FortSungard03 -  - Load cell FortSungard03', menu_idx: -4)
        expect_menu_items_to_include('[ ] FortSungard05 -  - Load cell FortSungard05', menu_idx: -4)
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
        expect_menu_items_to_include('[+] interior_cell - 0 / 1')
        expect_menu_items_to_include('[ ] FortSungard03 -  - Load cell FortSungard03', menu_idx: -4)
      end

      it 'runs in-game tests Locations' do
        run_and_discover(
          run: true,
          expect_tests: {
            locations: %w[fortsungard03]
          },
          mock_tests_statuses: {
            locations: {
              'fortsungard03' => 'ok'
            }
          },
          csv: <<~EO_CSV
            "test_game.esm",CELL,0001AB5F,coc,FortSungard03
            "mod1.esp",CELL,0001AB5F,coc,FortSungard03
          EO_CSV
        )
        expect_menu_items_to_include('[*] interior_cell - 1 / 1')
      end

    end

  end

end
