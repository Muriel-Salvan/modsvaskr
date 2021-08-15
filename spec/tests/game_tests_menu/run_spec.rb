describe 'Game tests menu' do

  context 'checking tests run' do

    around do |example|
      # Register the key sequence getting to the desired menu
      entering_menu_keys %w[KEY_ENTER KEY_ENTER] +
        # Discover tests
        %w[KEY_ENTER KEY_DOWN KEY_ENTER KEY_DOWN KEY_DOWN KEY_ENTER KEY_HOME]
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
        ModsvaskrTest::TestsSuites::TestsSuite.tests = {
          'test_1' => { name: 'Test 1' },
          'test_2' => { name: 'Test 2' },
          'test_3' => { name: 'Test 3' }
        }
        example.run
      end
    end

    before do
      set_test_tests_suites(%i[tests_suite in_game_tests_suite])
    end

    it 'runs selected tests' do
      ModsvaskrTest::TestsSuites::TestsSuite.mocked_statuses = {
        'test_2' => 'ok',
        'test_3' => 'ok'
      }
      run_modsvaskr(
        config: @config,
        # Select only test_2 and test_3
        keys: %w[KEY_DOWN KEY_ENTER KEY_ENTER d KEY_DOWN KEY_ENTER KEY_DOWN KEY_ENTER KEY_ESCAPE] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME KEY_DOWN d KEY_ESCAPE]
      )
      expect_menu_items_to_include('[*] in_game_tests_suite - 0 / 0')
      expect_menu_items_to_include('[+] tests_suite - 2 / 3')
      expect_menu_items_to_include('[ ] test_1 -  - Test 1', menu_idx: -4)
      expect_menu_items_to_include('[*] test_2 - ok - Test 2', menu_idx: -4)
      expect_menu_items_to_include('[*] test_3 - ok - Test 3', menu_idx: -4)
    end

    it 'runs selected tests with some non-ok statuses' do
      ModsvaskrTest::TestsSuites::TestsSuite.mocked_statuses = {
        'test_1' => 'ok',
        'test_2' => 'failed',
        'test_3' => 'error'
      }
      run_modsvaskr(
        config: @config,
        # Select all tests
        keys: %w[KEY_DOWN KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME KEY_DOWN d KEY_ESCAPE]
      )
      expect_menu_items_to_include('[*] in_game_tests_suite - 0 / 0')
      expect_menu_items_to_include('[*] tests_suite - 1 / 3')
      expect_menu_items_to_include('[*] test_1 - ok - Test 1', menu_idx: -4)
      expect_menu_items_to_include('[*] test_2 - failed - Test 2', menu_idx: -4)
      expect_menu_items_to_include('[*] test_3 - error - Test 3', menu_idx: -4)
    end

  end

end
