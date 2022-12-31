describe 'Game plugins menu' do

  context 'when checking the menu itself' do

    # Run the tests menu of a generic test game with the test tests suites.
    #
    # Parameters::
    # * *keys* (Array): Keys to be sent while in the menu
    def run_game_plugins_menu(keys)
      self.test_tests_suites = %i[tests_suite in_game_tests_suite]
      # Register the key sequence getting to the desired menu
      entering_menu_keys %w[KEY_ENTER KEY_ENTER]
      exiting_menu_keys %w[KEY_ESCAPE KEY_ESCAPE]
      menu_index_to_test(-3)
      with_game_dir do
        run_modsvaskr(
          config: {
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
            ]
          },
          keys:
        )
      end
    end

    it 'displays menu actions' do
      run_game_plugins_menu []
      expect_menu_title_to_include('Test Game > Plugins')
      expect_menu_items_to_include('Clean 0 selected plugins')
    end

    it 'displays ordered list of master plugins' do
      run_game_plugins_menu []
      expect_menu_item_to_include(0, '[ ] 0 - test_game.esm')
      expect_menu_item_to_include(1, '[ ] 1 - test_game_update.esm')
    end

    it 'displays ordered list of all plugins' do
      run_game_plugins_menu []
      expect_menu_item_to_include(0, '[ ] 0 - test_game.esm')
      expect_menu_item_to_include(1, '[ ] 1 - test_game_update.esm')
      expect_menu_item_to_include(2, '[ ] 2 - mod1.esp')
      expect_menu_item_to_include(3, '[ ] 3 - mod2.esp')
      expect_menu_item_to_include(4, '[ ] 4 - mod3.esp')
      expect_menu_item_to_include(5, '[ ] 5 - mod4.esp')
    end

    it 'selects plugins' do
      run_game_plugins_menu %w[
        KEY_DOWN
        KEY_ENTER
        KEY_DOWN
        KEY_DOWN
        KEY_ENTER
        KEY_DOWN
        KEY_ENTER
        KEY_UP
        KEY_ENTER
      ]
      expect_menu_item_to_include(0, '[ ] 0 - test_game.esm')
      expect_menu_item_to_include(1, '[*] 1 - test_game_update.esm')
      expect_menu_item_to_include(2, '[ ] 2 - mod1.esp')
      expect_menu_item_to_include(3, '[ ] 3 - mod2.esp')
      expect_menu_item_to_include(4, '[*] 4 - mod3.esp')
      expect_menu_item_to_include(5, '[ ] 5 - mod4.esp')
      expect_menu_items_to_include('Clean 2 selected plugins')
    end

  end

end
