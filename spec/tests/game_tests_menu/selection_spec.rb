describe 'Game tests menu' do

  context 'when checking tests selection' do

    # Run the tests menu of a generic test game with the test tests suites.
    # Use the discover_tests let flag to indicate that tests should be discovered.
    #
    # Parameters::
    # * *keys* (Array): Keys to be sent while in the menu
    def run_game_tests_menu(keys)
      self.test_tests_suites = %i[tests_suite in_game_tests_suite]
      # Register the key sequence getting to the desired menu
      entering_menu_keys %w[KEY_ENTER KEY_ENTER] + (discover_tests ? %w[KEY_ENTER KEY_DOWN KEY_ENTER KEY_DOWN KEY_DOWN KEY_ENTER KEY_HOME] : [])
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
          keys: keys
        )
      end
    end

    let(:discover_tests) { false }

    it 'selects tests suites' do
      run_game_tests_menu %w[KEY_ENTER KEY_DOWN KEY_ENTER]
      expect_menu_items_to_include('[*] in_game_tests_suite - 0 / 0')
      expect_menu_items_to_include('[*] tests_suite - 0 / 0')
    end

    context 'with test cases' do

      let(:discover_tests) { true }

      before do
        ModsvaskrTest::TestsSuites::TestsSuite.tests = {
          'test_1' => { name: 'Test 1' },
          'test_2' => { name: 'Test 2' },
          'test_3' => { name: 'Test 3' }
        }
        ModsvaskrTest::TestsSuites::InGameTestsSuite.tests = {
          'in_game_test_1' => { name: 'In-game test 1' },
          'in_game_test_2' => { name: 'In-game test 2' }
        }
      end

      it 'selects all tests from a tests suite' do
        run_game_tests_menu %w[KEY_DOWN KEY_ENTER]
        expect_menu_items_to_include('[+] in_game_tests_suite - 0 / 2')
        expect_menu_items_to_include('[*] tests_suite - 0 / 3')
      end

      it 'deselects all tests from a tests suite' do
        run_game_tests_menu %w[KEY_DOWN KEY_ENTER KEY_ENTER]
        expect_menu_items_to_include('[+] in_game_tests_suite - 0 / 2')
        expect_menu_items_to_include('[ ] tests_suite - 0 / 3')
      end

      it 'selects some tests from a tests suite' do
        run_game_tests_menu %w[KEY_DOWN KEY_ENTER KEY_ENTER d KEY_DOWN KEY_ENTER KEY_ESCAPE]
        expect_menu_items_to_include('[+] in_game_tests_suite - 0 / 2')
        expect_menu_items_to_include('[+] tests_suite - 0 / 3')
        expect_menu_items_to_include('[ ] test_1 -  - Test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] test_2 -  - Test 2', menu_idx: -4)
        expect_menu_items_to_include('[ ] test_3 -  - Test 3', menu_idx: -4)
      end

    end

  end

end
