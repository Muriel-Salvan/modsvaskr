describe 'Game tests menu' do

  context 'when checking tests suite plugin' do

    describe 'npc_head' do

      let(:tests_suite) { :npc_head }

      it 'discovers 1 test' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",NPC_,00014137,Angrenor Once-Honored
            "test_game.esm",TES4,
          EO_CSV
        )
        expect_menu_items_to_include('[+] npc_head - 0 / 1')
        expect_menu_items_to_include('[ ] test_game.esm/82231 -  - Take head screenshot of Angrenor Once-Honored - test_game.esm', menu_idx: -4)
      end

      it 'discovers 1 test having non-ASCI characters' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",NPC_,00014137,フォートサンガード
            "test_game.esm",TES4,
          EO_CSV
        )
        expect_menu_items_to_include('[+] npc_head - 0 / 1')
        expect_menu_items_to_include(%r{\[ \] test_game.esm/82231 -  - Take head screenshot of .+ - test_game.esm}, menu_idx: -4)
        # TODO: Use the following when ncurses will handle UTF-8 properly
        # rubocop:disable Style/AsciiComments
        # expect_menu_items_to_include('[ ] test_game.esm/82231 -  - Take head screenshot of フォートサンガード - test_game.esm', menu_idx: -4)
        # rubocop:enable Style/AsciiComments
      end

      it 'discovers 1 test per NPC even when mods modify the same NPC' do
        run_and_discover(
          csv: <<~EO_CSV
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
        )
        expect_menu_items_to_include('[+] npc_head - 0 / 3')
        expect_menu_items_to_include('[ ] test_game.esm/82225 -  - Take head screenshot of Angrenor1 - test_game.esm/mod1.esp/mod2.esp', menu_idx: -4)
        expect_menu_items_to_include('[ ] test_game.esm/82226 -  - Take head screenshot of Angrenor2 - test_game.esm/mod2.esp', menu_idx: -4)
        expect_menu_items_to_include('[ ] mod3.esp/82227 -  - Take head screenshot of Angrenor3 - mod3.esp/mod4.esp', menu_idx: -4)
      end

      it 'ignores other data dump when discovering tests' do
        run_and_discover(
          csv: <<~EO_CSV
            "test_game.esm",CELL,0001AB5F,coc,FortSungard03
            "test_game.esm",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
            "test_game.esm",NPC_,00014137,Angrenor Once-Honored
            "test_game.esm",TES4,
            "mod1.esp",CELL,00106666,cow,LabyrinthianMazeWorld,0,0
            "mod1.esp",CELL,0001AB5F,coc,FortSungard03
            "mod1.esp",TES4,,test_game.esm
          EO_CSV
        )
        expect_menu_items_to_include('[+] npc_head - 0 / 1')
        expect_menu_items_to_include('[ ] test_game.esm/82231 -  - Take head screenshot of Angrenor Once-Honored - test_game.esm', menu_idx: -4)
      end

      it 'fails when masters could not be parsed' do
        expect do
          run_and_discover(
            csv: <<~EO_CSV
              "test_game.esm",NPC_,00014137,Angrenor Once-Honored
            EO_CSV
          )
        end.to raise_error 'Esp test_game.esm declares NPC FormID 82231 (Angrenor Once-Honored) but its masters could not be parsed'
      end

      it 'fails when masters are parsed incorrectly' do
        expect do
          run_and_discover(
            csv: <<~EO_CSV
              "test_game.esm",TES4,
              "mod1.esp",TES4,,test_game.esm
              "mod2.esp",TES4,,test_game.esm
              "mod3.esp",NPC_,04014133,Angrenor3
              "mod3.esp",TES4,,test_game.esm,mod1.esp,mod2.esp
            EO_CSV
          )
        end.to raise_error 'NPC FormID 67191091 (Angrenor3) from mod3.esp references an unknown master (known masters: test_game.esm, mod1.esp, mod2.esp)'
      end

      it 'runs in-game tests NPCsHead' do
        run_and_discover(
          run: true,
          expect_tests: {
            npcshead: %w[test_game.esm/82231]
          },
          mock_tests_statuses: {
            npcshead: {
              'test_game.esm/82231' => 'ok'
            }
          },
          csv: <<~EO_CSV
            "test_game.esm",NPC_,00014137,Angrenor Once-Honored
            "test_game.esm",TES4,
          EO_CSV
        )
        expect_menu_items_to_include('[*] npc_head - 1 / 1')
      end

    end

  end

end
