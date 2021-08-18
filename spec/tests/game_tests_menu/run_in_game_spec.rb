describe 'Game tests menu' do

  context 'when checking in-game test run' do

    # Run the tests menu of a generic test game with the test tests suites.
    #
    # Parameters::
    # * *keys* (Array): Keys to be sent while in the menu
    def run_game_tests_menu(keys)
      ModsvaskrTest::TestsSuites::InGameTestsSuite.tests = {
        'in_game_test_1' => { name: 'In-game test 1' },
        'in_game_test_2' => { name: 'In-game test 2' },
        'in_game_test_3' => { name: 'In-game test 3' },
        'in_game_test_4' => { name: 'In-game test 4' }
      }
      self.test_tests_suites = %i[in_game_tests_suite]
      # Register the key sequence getting to the desired menu
      entering_menu_keys %w[KEY_ENTER KEY_ENTER] +
        # Discover tests
        %w[KEY_ENTER KEY_DOWN KEY_DOWN KEY_ENTER KEY_HOME]
      exiting_menu_keys %w[KEY_ESCAPE KEY_ESCAPE]
      menu_index_to_test(-3)
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
              'timeout_frozen_tests_secs' => 2,
              'timeout_interrupt_tests_secs' => 1
            }
          ]
        },
        keys: keys
      )
    end

    around do |example|
      with_game_dir do
        example.run
      end
    end

    it 'does not run in-game tests if AutoTest is not installed' do
      # Select only in_game_test_2
      run_game_tests_menu %w[KEY_ENTER KEY_ENTER d KEY_DOWN KEY_ENTER KEY_ESCAPE] +
        # Run tests
        %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
        # Check tests statuses
        %w[KEY_HOME d KEY_ESCAPE]
      expect_menu_items_to_include('[+] in_game_tests_suite - 0 / 4')
      expect_menu_items_to_include('[ ] in_game_test_1 -  - In-game test 1', menu_idx: -4)
      expect_menu_items_to_include('[*] in_game_test_2 -  - In-game test 2', menu_idx: -4)
      expect_menu_items_to_include('[ ] in_game_test_3 -  - In-game test 3', menu_idx: -4)
      expect_menu_items_to_include('[ ] in_game_test_4 -  - In-game test 4', menu_idx: -4)
      expect_logs_to_include(%r{Missing file #{Regexp.escape(game_dir)}/Data/AutoTest\.esp\. In-game tests will be disabled\. Please install the AutoTest mod\.})
    end

    context 'when running in-game tests' do

      it 'runs 1 selected in-game test' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_2]
          { autotestsuite_2: %w[autotest_21] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_2]
          expect(auto_test_statuses).to eq(autotestsuite_2: { 'autotest_21' => 'ok' })
          [%w[in_game_test_2 ok]]
        end
        mock_in_game_tests_run(
          expect_tests: { autotestsuite_2: %w[autotest_21] },
          mock_tests_statuses: { autotestsuite_2: { 'autotest_21' => 'ok' } }
        )
        # Select only in_game_test_2
        run_game_tests_menu %w[KEY_ENTER KEY_ENTER d KEY_DOWN KEY_ENTER KEY_ESCAPE] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[+] in_game_tests_suite - 1 / 4')
        expect_menu_items_to_include('[ ] in_game_test_1 -  - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[ ] in_game_test_3 -  - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[ ] in_game_test_4 -  - In-game test 4', menu_idx: -4)
      end

      it 'runs several selected in-game tests from different tests suites' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          {
            autotestsuite_1: %w[autotest_11],
            autotestsuite_2: %w[autotest_21 autotest_22]
          }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          if auto_test_statuses.key?(:autotestsuite_1)
            expect(auto_test_statuses).to eq(autotestsuite_1: { 'autotest_11' => 'ok' })
            [
              %w[in_game_test_1 ok],
              %w[in_game_test_2 ok]
            ]
          else
            expect(auto_test_statuses).to eq(
              autotestsuite_2: {
                'autotest_21' => 'ok',
                'autotest_22' => 'ok'
              }
            )
            [
              %w[in_game_test_3 ok],
              %w[in_game_test_4 ok]
            ]
          end
        end
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_11],
            autotestsuite_2: %w[autotest_21 autotest_22]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_11' => 'ok'
            },
            autotestsuite_2: {
              'autotest_21' => 'ok',
              'autotest_22' => 'ok'
            }
          }
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'ignores selected in-game tests statuses from tests suites that were not asked' do
        # This can happen when the user has some in-game test status files in their data directory
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          {
            autotestsuite_1: %w[autotest_11]
          }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses).to eq(autotestsuite_1: { 'autotest_11' => 'ok' })
          [
            %w[in_game_test_1 ok],
            %w[in_game_test_2 ok],
            %w[in_game_test_3 ok],
            %w[in_game_test_4 ok]
          ]
        end
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_11]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_11' => 'ok'
            },
            autotestsuite_2: {
              'autotest_21' => 'ok',
              'autotest_22' => 'ok'
            }
          }
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'clears statuses of required in-game tests before running in-game testing' do
        # Simulate a previous run that has put statuses
        FileUtils.mkdir_p "#{game_dir}/Data/SKSE/Plugins/StorageUtilData"
        File.write(
          "#{game_dir}/Data/SKSE/Plugins/StorageUtilData/AutoTest_autotestsuite_1_Statuses.json",
          {
            string: {
              autotest_11: 'old_ok',
              autotest_12: 'ok',
              autotest_13: 'old_ok',
              autotest_14: 'ok'
            }
          }.to_json
        )
        FileUtils.mkdir_p "#{game_dir}/Data/Modsvaskr/Tests"
        File.write(
          "#{game_dir}/Data/Modsvaskr/Tests/Statuses_in_game_tests_suite.json",
          [
            %w[in_game_test_1 old_ok],
            %w[in_game_test_2 ok],
            %w[in_game_test_3 old_ok],
            %w[in_game_test_4 ok]
          ].to_json
        )
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_3 in_game_test_4]
          {
            autotestsuite_1: %w[autotest_13 autotest_14]
          }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_3 in_game_test_4]
          expect(auto_test_statuses).to eq(autotestsuite_1: { 'autotest_13' => 'ok', 'autotest_14' => 'ok' })
          [
            %w[in_game_test_3 ok],
            %w[in_game_test_4 ok]
          ]
        end
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_13 autotest_14]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_13' => 'ok',
              'autotest_14' => 'ok'
            }
          }
        )
        # Select only in_game_test_3 and in_game_test_4
        run_game_tests_menu %w[KEY_ENTER d KEY_DOWN KEY_DOWN KEY_ENTER KEY_DOWN KEY_ENTER KEY_ESCAPE] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[+] in_game_tests_suite - 3 / 4')
        expect_menu_items_to_include('[ ] in_game_test_1 - old_ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[ ] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'runs several selected in-game tests from different tests suites with some failures' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          {
            autotestsuite_1: %w[autotest_11],
            autotestsuite_2: %w[autotest_21 autotest_22]
          }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          if auto_test_statuses.key?(:autotestsuite_1)
            expect(auto_test_statuses).to eq(autotestsuite_1: { 'autotest_11' => 'ok' })
            [
              %w[in_game_test_1 ok],
              %w[in_game_test_2 ok]
            ]
          else
            expect(auto_test_statuses).to eq(
              autotestsuite_2: {
                'autotest_21' => 'failed',
                'autotest_22' => 'ok'
              }
            )
            [
              %w[in_game_test_3 failed],
              %w[in_game_test_4 ok]
            ]
          end
        end
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_11],
            autotestsuite_2: %w[autotest_21 autotest_22]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_11' => 'ok'
            },
            autotestsuite_2: {
              'autotest_21' => 'failed',
              'autotest_22' => 'ok'
            }
          }
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 3 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - failed - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'runs several tests and get their statuses through several checks' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite_1].sort
          auto_test_statuses[:autotestsuite_1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a CTD: autotest_3 and autotest_4 have not been run, and the ending status is still 'run'
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: [
            { autotestsuite_1: { 'autotest_1' => 'failed', 'autotest_2' => 'ok' } },
            { autotestsuite_1: { 'autotest_3' => 'ok' } },
            { autotestsuite_1: { 'autotest_4' => 'ok' } }
          ]
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 3 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - failed - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'interrupts in-game tests when the user stopped the session from the game' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite_1].sort
          auto_test_statuses[:autotestsuite_1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a stop done by the user in the middle of the test session, after autotest_2 run
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_1' => 'ok',
              'autotest_2' => 'ok'
            }
          },
          mock_tests_execution_stopped_by_user: true
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 2 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 -  - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 -  - In-game test 4', menu_idx: -4)
      end

      it 'restarts in-game tests when the game has done a CTD in the middle of a tests session' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite_1].sort
          auto_test_statuses[:autotestsuite_1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a CTD: autotest_3 and autotest_4 have not been run, and the ending status is still 'run'
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_1' => 'ok',
              'autotest_2' => 'ok'
            }
          },
          mock_tests_execution_end: 'run'
        )
        # So we expect another run to be done for remaining in-game tests
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_3' => 'ok',
              'autotest_4' => 'ok'
            }
          },
          mock_tests_execution_end: 'end'
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'restarts in-game tests when the game has done a CTD in the middle of a started test' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite_1].sort
          auto_test_statuses[:autotestsuite_1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a CTD: autotest_4 (the last test) has started, and the ending status is still 'run'
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_1' => 'ok',
              'autotest_2' => 'ok',
              'autotest_3' => 'ok',
              'autotest_4' => 'started'
            }
          },
          mock_tests_execution_end: 'run'
        )
        # So we expect another run to be done for remaining in-game tests
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_4' => 'ok'
            }
          },
          mock_tests_execution_end: 'end'
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'skips in-game tests that keep provoking CTDs' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite_1].sort
          auto_test_statuses[:autotestsuite_1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a CTD: autotest_3 and autotest_4 have not been run, and the ending status is still 'run'
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_1' => 'ok',
              'autotest_2' => 'ok'
            }
          },
          mock_tests_execution_end: 'run'
        )
        # So we expect another run to be done for remaining in-game tests, but we make it fail at the same test
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_execution_end: 'run'
        )
        # autotest_3 should be marked as failed_ctd, then updating statuses again
        mock_system_calls [mock_list_storage]
        # So we expect another run to be done for remaining in-game tests, skipping autotest_3
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_4' => 'ok'
            }
          },
          mock_tests_execution_end: 'end'
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 3 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - failed_ctd - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'skips in-game tests that keep provoking CTDs with case-insensitive test names' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite_1: %w[AutoTest_1 AutoTest_2 AutoTest_3 AutoTest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite_1].sort
          auto_test_statuses[:autotestsuite_1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a CTD: autotest_3 and autotest_4 have not been run, and the ending status is still 'run'
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              # Simulate the Papyrus has output JSON keys with a different case
              'AutoTest_1' => 'ok',
              'AutoTest_2' => 'ok'
            }
          },
          mock_tests_execution_end: 'run'
        )
        # So we expect another run to be done for remaining in-game tests, but we make it fail at the same test
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_execution_end: 'run'
        )
        # autotest_3 should be marked as failed_ctd, then updating statuses again
        mock_system_calls [mock_list_storage]
        # So we expect another run to be done for remaining in-game tests, skipping autotest_3
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'AutoTest_4' => 'ok'
            }
          },
          mock_tests_execution_end: 'end'
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 3 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - failed_ctd - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'detects hung game and restarts it' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite_1].sort
          auto_test_statuses[:autotestsuite_1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a stuck game: autotest_1 gets updated but no other status will get updated for at least 3 seconds (3 iterations)
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: [
            { autotestsuite_1: { 'autotest_1' => 'ok' } },
            {},
            {}
          ],
          mock_tests_execution_end: 'run',
          mock_exit_game: false
        )
        # We expect the game to be killed
        mock_system_calls [
          ['taskkill /pid 1107', ''],
          ['tasklist | find "TestGame.exe"', ''],
          mock_list_storage
        ]
        # So we expect another run to be done for remaining in-game tests
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_2' => 'ok',
              'autotest_3' => 'ok',
              'autotest_4' => 'ok'
            }
          }
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'detects hung game and restarts it with several attempts' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite_1].sort
          auto_test_statuses[:autotestsuite_1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a stuck game: autotest_1 gets updated but no other status will get updated for at least 3 seconds (3 iterations)
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: [
            { autotestsuite_1: { 'autotest_1' => 'ok' } },
            {},
            {}
          ],
          mock_tests_execution_end: 'run',
          mock_exit_game: false
        )
        # We expect the game to be killed, but it takes several attempts
        mock_system_calls [
          ['taskkill /pid 1107', ''],
          ['tasklist | find "TestGame.exe"', 'TestGame.exe 1107'],
          ['taskkill /F /pid 1107', ''],
          ['tasklist | find "TestGame.exe"', 'TestGame.exe 1107'],
          ['taskkill /F /pid 1107', ''],
          ['tasklist | find "TestGame.exe"', ''],
          mock_list_storage
        ]
        # So we expect another run to be done for remaining in-game tests
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_2' => 'ok',
              'autotest_3' => 'ok',
              'autotest_4' => 'ok'
            }
          }
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'skips in-game tests that keep hanging the game' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite_1].sort
          auto_test_statuses[:autotestsuite_1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate autotest_2 hanging game repeatedly
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: [
            { autotestsuite_1: { 'autotest_1' => 'ok' } },
            {},
            {}
          ],
          mock_tests_execution_end: 'run',
          mock_exit_game: false
        )
        # We expect the game to be killed
        mock_system_calls [
          ['taskkill /pid 1107', ''],
          ['tasklist | find "TestGame.exe"', ''],
          mock_list_storage
        ]
        # So we expect another run to be done for remaining in-game tests, but we make it hang at the same test
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: [
            {},
            {},
            {}
          ],
          mock_tests_execution_end: 'run',
          mock_exit_game: false
        )
        # We expect the game to be killed again
        mock_system_calls [
          ['taskkill /pid 1107', ''],
          ['tasklist | find "TestGame.exe"', ''],
          mock_list_storage
        ]
        # autotest_2 should be marked as failed_ctd, then updating statuses again
        mock_system_calls [mock_list_storage]
        # So we expect another run to be done for remaining in-game tests, skipping autotest_3
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite_1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite_1: {
              'autotest_3' => 'ok',
              'autotest_4' => 'ok'
            }
          },
          mock_tests_execution_end: 'end'
        )
        # Select all in-game tests
        run_game_tests_menu %w[KEY_ENTER] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
        expect_menu_items_to_include('[*] in_game_tests_suite - 3 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - failed_ctd - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

    end

  end

end
