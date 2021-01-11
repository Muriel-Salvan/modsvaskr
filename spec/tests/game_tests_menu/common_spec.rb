describe 'Game tests menu' do

  context 'checking the menu itself' do

    around(:each) do |example|
      # Register the key sequence getting to the desired menu
      entering_menu_keys %w[KEY_ENTER KEY_ENTER]
      exiting_menu_keys %w[KEY_ESCAPE KEY_ESCAPE]
      menu_index_to_test -3
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

    it 'displays available tests suites and menu' do
      run_modsvaskr(config: @config)
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

      before(:each) do
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
        run_modsvaskr(
          config: @config,
          keys: %w[KEY_ENTER KEY_DOWN KEY_ENTER KEY_DOWN KEY_DOWN KEY_ENTER]
        )
        expect_menu_items_to_include('[+] in_game_tests_suite - 0 / 2')
        expect_menu_items_to_include('[+] tests_suite - 0 / 3')
      end

    end

  end

end
