describe 'Game tests menu' do

  context 'when checking the menu itself' do

    # Run the tests menu of a generic test game with the test tests suites.
    #
    # Parameters::
    # * *keys* (Array): Keys to be sent while in the menu
    def run_game_tests_menu(keys)
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

    it 'displays available tests suites and menu' do
      run_game_tests_menu []
      expect_menu_title_to_include('Test Game > Testing')
      expect_menu_items_to_include('[ ] tests_suite - 0 / 0')
      expect_menu_items_to_include('[ ] in_game_tests_suite - 0 / 0')
      expect_menu_items_to_include('Select tests that are not ok')
      expect_menu_items_to_include('Register tests from selected test suites')
      expect_menu_items_to_include('Unregister tests from selected test suites')
      expect_menu_items_to_include('Clear selected test statuses')
      expect_menu_items_to_include('Run remaining selected tests')
    end

    context 'with test cases' do

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

      it 'discovers tests' do
        run_game_tests_menu %w[KEY_ENTER KEY_DOWN KEY_ENTER KEY_DOWN KEY_DOWN KEY_ENTER]
        expect_menu_items_to_include('[+] in_game_tests_suite - 0 / 2')
        expect_menu_items_to_include('[+] tests_suite - 0 / 3')
      end

    end

  end

end
