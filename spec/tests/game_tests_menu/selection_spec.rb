describe 'Game tests menu' do

  context 'checking tests selection' do

    around do |example|
      # Register the key sequence getting to the desired menu
      entering_menu_keys %w[KEY_ENTER KEY_ENTER]
      exiting_menu_keys %w[KEY_ESCAPE KEY_ESCAPE]
      menu_index_to_test(-3)
      with_tmp_dir('test_game') do |game_dir|
        @game_dir = game_dir
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
          ]
        }
        example.run
      end
    end

    before do
      set_test_tests_suites(%i[tests_suite in_game_tests_suite])
    end

    it 'selects tests suites' do
      run_modsvaskr(
        config: @config,
        keys: %w[KEY_ENTER KEY_DOWN KEY_ENTER]
      )
      expect_menu_items_to_include('[*] in_game_tests_suite - 0 / 0')
      expect_menu_items_to_include('[*] tests_suite - 0 / 0')
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
        # Discover tests
        entering_menu_keys(@menu_enter_keys + %w[KEY_ENTER KEY_DOWN KEY_ENTER KEY_DOWN KEY_DOWN KEY_ENTER KEY_HOME])
      end

      it 'selects all tests from a tests suite' do
        run_modsvaskr(
          config: @config,
          keys: %w[KEY_DOWN KEY_ENTER]
        )
        expect_menu_items_to_include('[+] in_game_tests_suite - 0 / 2')
        expect_menu_items_to_include('[*] tests_suite - 0 / 3')
      end

      it 'deselects all tests from a tests suite' do
        run_modsvaskr(
          config: @config,
          keys: %w[KEY_DOWN KEY_ENTER KEY_ENTER]
        )
        expect_menu_items_to_include('[+] in_game_tests_suite - 0 / 2')
        expect_menu_items_to_include('[ ] tests_suite - 0 / 3')
      end

      it 'selects some tests from a tests suite' do
        run_modsvaskr(
          config: @config,
          keys: %w[KEY_DOWN KEY_ENTER KEY_ENTER d KEY_DOWN KEY_ENTER KEY_ESCAPE]
        )
        expect_menu_items_to_include('[+] in_game_tests_suite - 0 / 2')
        expect_menu_items_to_include('[+] tests_suite - 0 / 3')
        expect_menu_items_to_include('[ ] test_1 -  - Test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] test_2 -  - Test 2', menu_idx: -4)
        expect_menu_items_to_include('[ ] test_3 -  - Test 3', menu_idx: -4)
      end

    end

  end

end
