describe 'Game tests menu' do

  context 'checking in-game test run' do

    around(:each) do |example|
      # Register the key sequence getting to the desired menu
      entering_menu_keys %w[KEY_ENTER KEY_ENTER] +
        # Discover tests
        %w[KEY_ENTER KEY_DOWN KEY_ENTER KEY_DOWN KEY_DOWN KEY_ENTER KEY_HOME]
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
              'timeout_frozen_tests_secs' => 2,
              'timeout_interrupt_tests_secs' => 1
            }
          ]
        }
        ModsvaskrTest::TestsSuites::InGameTestsSuite.tests = {
          'in_game_test_1' => { name: 'In-game test 1' },
          'in_game_test_2' => { name: 'In-game test 2' },
          'in_game_test_3' => { name: 'In-game test 3' },
          'in_game_test_4' => { name: 'In-game test 4' }
        }
        example.run
      end
    end

    it 'does not run in-game tests if AutoTest is not installed' do
      run_modsvaskr(
        config: @config,
        # Select only in_game_test_2
        keys: %w[KEY_ENTER KEY_ENTER d KEY_DOWN KEY_ENTER KEY_ESCAPE] +
          # Run tests
          %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
          # Check tests statuses
          %w[KEY_HOME d KEY_ESCAPE]
      )
      expect_menu_items_to_include('[+] in_game_tests_suite - 0 / 4')
      expect_menu_items_to_include('[ ] in_game_test_1 -  - In-game test 1', menu_idx: -4)
      expect_menu_items_to_include('[*] in_game_test_2 -  - In-game test 2', menu_idx: -4)
      expect_menu_items_to_include('[ ] in_game_test_3 -  - In-game test 3', menu_idx: -4)
      expect_menu_items_to_include('[ ] in_game_test_4 -  - In-game test 4', menu_idx: -4)
      expect_logs_to_include(/Missing file #{Regexp.escape(@game_dir)}\/Data\/AutoTest\.esp\. In-game tests will be disabled\. Please install the AutoTest mod\./)
    end

    context 'running in-game tests' do

      # Get the mocked command listing storage
      #
      # Result::
      # * [String, Proc]: Mocked command to be used to list storage of the game
      def mock_list_storage
        storage_util_dir = "#{@game_dir}/Data/SKSE/Plugins/StorageUtilData"
        [
          "dir \"#{storage_util_dir}\" /B",
          proc { Dir.glob("#{storage_util_dir}/*").map { |f| File.basename(f) }.join("\n") }
        ]
      end

      # Mock a game runnning an in-game tests session
      #
      # Parameters::
      # * *expect_game_launch_cmd* (String): Expected game launch command [default: '"game_launcher.exe"']
      # * *expect_tests* (Hash<Symbol,Array<String>>): Expected list of in-game tests to be run, per in-game tests suite [default: {}]
      # * *mock_tests_statuses* (Hash<Symbol, Hash<String, String> > or Array): List of (or single) set of in-game tests statuses, per in-game test name, per in-game tests suite [default: {}]
      # * *mock_tests_execution_end* (String): Status to set at the end of this in-game tests execution [default: 'end']
      # * *mock_tests_execution_stopped_by_user* (Boolean): If tru, the mock an interruption done by the user [default: false]
      # * *mock_exit_game* (Boolean): If true, then mock that the game exited [default: true]
      def mock_in_game_tests_run(
        expect_game_launch_cmd: '"game_launcher.exe"',
        expect_tests: {},
        mock_tests_statuses: {},
        mock_tests_execution_end: 'end',
        mock_tests_execution_stopped_by_user: false,
        mock_exit_game: true
      )
        mock_tests_statuses = [mock_tests_statuses] unless mock_tests_statuses.is_a?(Array)
        storage_util_dir = "#{@game_dir}/Data/SKSE/Plugins/StorageUtilData"
        mock_system_calls [
          # Get AutoTest statuses
          mock_list_storage,
          # Launch game
          [expect_game_launch_cmd, ''],
          ['tasklist | find "TestGame.exe"', 'TestGame.exe 1107']
        ]
        mock_tests_statuses.each.with_index do |mock_tests_statuses_iteration, idx|
          last_iteration = (idx == mock_tests_statuses.size - 1)
          mock_system_calls [
            # Check if running
            # If it is the last iteration, consider it has exited normally
            ['tasklist | find "TestGame.exe"', last_iteration && mock_exit_game ? '' : 'TestGame.exe 1107'],
            # Get AutoTest statuses
            [mock_list_storage[0], proc do
              # Check that we ask to run the correct tests
              expect(Dir.glob("#{storage_util_dir}/AutoTest_*_Run.json").map { |f| File.basename(f).downcase }.sort).to eq(
                expect_tests.keys.map { |in_game_tests_suite| "autotest_#{in_game_tests_suite}_run.json" }.sort
              )
              expect_tests.each do |in_game_tests_suite, in_game_tests|
                expect(JSON.parse(File.read("#{storage_util_dir}/AutoTest_#{in_game_tests_suite}_Run.json"))).to eq(
                  'stringList' => {
                    'tests_to_run' => in_game_tests
                  }
                )
              end
              # Here we mock test statuses
              FileUtils.mkdir_p storage_util_dir
              mock_tests_statuses_iteration.each do |in_game_tests_suite, in_game_tests_statuses|
                statuses_file = "#{storage_util_dir}/AutoTest_#{in_game_tests_suite}_Statuses.json"
                File.write(
                  statuses_file,
                  { string: (File.exist?(statuses_file) ? JSON.parse(File.read(statuses_file))['string'] : {}).merge(in_game_tests_statuses) }.to_json
                )
              end
              # If it is the last iteration, mock ending the tests session
              if last_iteration
                config = { tests_execution: mock_tests_execution_end }
                config[:stopped_by] = 'user' if mock_tests_execution_stopped_by_user
                File.write("#{storage_util_dir}/AutoTest_Config.json", { string: config }.to_json)
              end
              mock_list_storage[1].call
            end]
          ]
        end
      end

      before(:each) do
        # Create the AutoTest plugin
        expect(ElderScrollsPlugin).to receive(:new).with("#{@game_dir}/Data/AutoTest.esp") do
          mocked_esp = double('AutoTest esp plugin')
          expect(mocked_esp).to receive(:to_json) do
            {
              sub_chunks: [
                {
                  decoded_header: {
                    label: 'QUST'
                  },
                  sub_chunks: [
                    {
                      sub_chunks: [
                        {
                          name: 'EDID',
                          data: 'AutoTest_ScriptsQuest'
                        },
                        {
                          name: 'VMAD',
                          data: Base64.encode64('AutoTest_Suite_AutoTestSuite1|AutoTest_Suite_AutoTestSuite2')
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          end
          mocked_esp
        end
        FileUtils.mkdir_p "#{@game_dir}/Data"
        File.write("#{@game_dir}/Data/AutoTest.esp", 'Fake AutoTest.esp')
        # Create the AutoLoad plugin
        File.write("#{@game_dir}/Data/AutoLoad.cmd", 'Fake AutoLoad.cmd')
      end

      it 'runs 1 selected in-game test' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_2]
          { autotestsuite2: %w[autotest_21] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_2]
          expect(auto_test_statuses).to eq(autotestsuite2: { 'autotest_21' => 'ok' })
          [['in_game_test_2', 'ok']]
        end
        mock_in_game_tests_run(
          expect_tests: { autotestsuite2: %w[autotest_21] },
          mock_tests_statuses: { autotestsuite2: { 'autotest_21' => 'ok' } }
        )
        run_modsvaskr(
          config: @config,
          # Select only in_game_test_2
          keys: %w[KEY_ENTER KEY_ENTER d KEY_DOWN KEY_ENTER KEY_ESCAPE] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
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
            autotestsuite1: %w[autotest_11],
            autotestsuite2: %w[autotest_21 autotest_22]
          }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          if auto_test_statuses.key?(:autotestsuite1)
            expect(auto_test_statuses).to eq(autotestsuite1: { 'autotest_11' => 'ok' })
            [
              ['in_game_test_1', 'ok'],
              ['in_game_test_2', 'ok']
            ]
          else
            expect(auto_test_statuses).to eq(autotestsuite2: {
              'autotest_21' => 'ok',
              'autotest_22' => 'ok'
            })
            [
              ['in_game_test_3', 'ok'],
              ['in_game_test_4', 'ok']
            ]
          end
        end
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite1: %w[autotest_11],
            autotestsuite2: %w[autotest_21 autotest_22]
          },
          mock_tests_statuses: {
            autotestsuite1: {
              'autotest_11' => 'ok'
            },
            autotestsuite2: {
              'autotest_21' => 'ok',
              'autotest_22' => 'ok'
            }
          }
        )
        run_modsvaskr(
          config: @config,
          # Select all in-game tests
          keys: %w[KEY_ENTER] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'runs several selected in-game tests from different tests suites with some failures' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          {
            autotestsuite1: %w[autotest_11],
            autotestsuite2: %w[autotest_21 autotest_22]
          }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          if auto_test_statuses.key?(:autotestsuite1)
            expect(auto_test_statuses).to eq(autotestsuite1: { 'autotest_11' => 'ok' })
            [
              ['in_game_test_1', 'ok'],
              ['in_game_test_2', 'ok']
            ]
          else
            expect(auto_test_statuses).to eq(autotestsuite2: {
              'autotest_21' => 'failed',
              'autotest_22' => 'ok'
            })
            [
              ['in_game_test_3', 'failed'],
              ['in_game_test_4', 'ok']
            ]
          end
        end
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite1: %w[autotest_11],
            autotestsuite2: %w[autotest_21 autotest_22]
          },
          mock_tests_statuses: {
            autotestsuite1: {
              'autotest_11' => 'ok'
            },
            autotestsuite2: {
              'autotest_21' => 'failed',
              'autotest_22' => 'ok'
            }
          }
        )
        run_modsvaskr(
          config: @config,
          # Select all in-game tests
          keys: %w[KEY_ENTER] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
        expect_menu_items_to_include('[*] in_game_tests_suite - 3 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - failed - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'runs several tests and get their statuses through several checks' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite1].sort
          auto_test_statuses[:autotestsuite1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a CTD: autotest_3 and autotest_4 have not been run, and the ending status is still 'run'
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: [
            { autotestsuite1: { 'autotest_1' => 'failed', 'autotest_2' => 'ok' } },
            { autotestsuite1: { 'autotest_3' => 'ok' } },
            { autotestsuite1: { 'autotest_4' => 'ok' } }
          ]
        )
        run_modsvaskr(
          config: @config,
          # Select all in-game tests
          keys: %w[KEY_ENTER] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
        expect_menu_items_to_include('[*] in_game_tests_suite - 3 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - failed - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'interrupts in-game tests when the user stopped the session from the game' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite1].sort
          auto_test_statuses[:autotestsuite1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a stop done by the user in the middle of the test session, after autotest_2 run
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite1: {
              'autotest_1' => 'ok',
              'autotest_2' => 'ok'
            }
          },
          mock_tests_execution_stopped_by_user: true
        )
        run_modsvaskr(
          config: @config,
          # Select all in-game tests
          keys: %w[KEY_ENTER] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
        expect_menu_items_to_include('[*] in_game_tests_suite - 2 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 -  - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 -  - In-game test 4', menu_idx: -4)
      end

      it 'restarts in-game tests when the game has done a CTD in the middle of a tests session' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite1].sort
          auto_test_statuses[:autotestsuite1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a CTD: autotest_3 and autotest_4 have not been run, and the ending status is still 'run'
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite1: {
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
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite1: {
              'autotest_3' => 'ok',
              'autotest_4' => 'ok'
            }
          },
          mock_tests_execution_end: 'end'
        )
        run_modsvaskr(
          config: @config,
          # Select all in-game tests
          keys: %w[KEY_ENTER] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'restarts in-game tests when the game has done a CTD in the middle of a started test' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite1].sort
          auto_test_statuses[:autotestsuite1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a CTD: autotest_4 (the last test) has started, and the ending status is still 'run'
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite1: {
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
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite1: {
              'autotest_4' => 'ok'
            }
          },
          mock_tests_execution_end: 'end'
        )
        run_modsvaskr(
          config: @config,
          # Select all in-game tests
          keys: %w[KEY_ENTER] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'skips in-game tests that keep provoking CTDs' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite1].sort
          auto_test_statuses[:autotestsuite1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a CTD: autotest_3 and autotest_4 have not been run, and the ending status is still 'run'
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite1: {
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
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_execution_end: 'run'
        )
        # autotest_3 should be marked as failed_ctd, then updating statuses again
        mock_system_calls [mock_list_storage]
        # So we expect another run to be done for remaining in-game tests, skipping autotest_3
        mock_in_game_tests_run(
          expect_game_launch_cmd: '"Data\AutoLoad.cmd" auto_test',
          expect_tests: {
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite1: {
              'autotest_4' => 'ok'
            }
          },
          mock_tests_execution_end: 'end'
        )
        run_modsvaskr(
          config: @config,
          # Select all in-game tests
          keys: %w[KEY_ENTER] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
        expect_menu_items_to_include('[*] in_game_tests_suite - 3 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - failed_ctd - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'detects hung game and restarts it' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite1].sort
          auto_test_statuses[:autotestsuite1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a stuck game: autotest_1 gets updated but no other status will get updated for at least 3 seconds (3 iterations)
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: [
            { autotestsuite1: { 'autotest_1' => 'ok' } },
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
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite1: {
              'autotest_2' => 'ok',
              'autotest_3' => 'ok',
              'autotest_4' => 'ok'
            }
          }
        )
        run_modsvaskr(
          config: @config,
          # Select all in-game tests
          keys: %w[KEY_ENTER] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'detects hung game and restarts it with several attempts' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite1].sort
          auto_test_statuses[:autotestsuite1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate a stuck game: autotest_1 gets updated but no other status will get updated for at least 3 seconds (3 iterations)
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: [
            { autotestsuite1: { 'autotest_1' => 'ok' } },
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
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite1: {
              'autotest_2' => 'ok',
              'autotest_3' => 'ok',
              'autotest_4' => 'ok'
            }
          }
        )
        run_modsvaskr(
          config: @config,
          # Select all in-game tests
          keys: %w[KEY_ENTER] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
        expect_menu_items_to_include('[*] in_game_tests_suite - 4 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - ok - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

      it 'skips in-game tests that keep hanging the game' do
        ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = proc do |tests|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          { autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4] }
        end
        ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = proc do |tests, auto_test_statuses|
          expect(tests).to eq %w[in_game_test_1 in_game_test_2 in_game_test_3 in_game_test_4]
          expect(auto_test_statuses.keys.sort).to eq %i[autotestsuite1].sort
          auto_test_statuses[:autotestsuite1].map { |in_game_test, in_game_test_status| ["in_game_test_#{in_game_test.match(/autotest_(\d)/)[1]}", in_game_test_status] }
        end
        # Here we simulate autotest_2 hanging game repeatedly
        mock_in_game_tests_run(
          expect_tests: {
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: [
            { autotestsuite1: { 'autotest_1' => 'ok' } },
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
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
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
            autotestsuite1: %w[autotest_1 autotest_2 autotest_3 autotest_4]
          },
          mock_tests_statuses: {
            autotestsuite1: {
              'autotest_3' => 'ok',
              'autotest_4' => 'ok'
            }
          },
          mock_tests_execution_end: 'end'
        )
        run_modsvaskr(
          config: @config,
          # Select all in-game tests
          keys: %w[KEY_ENTER] +
            # Run tests
            %w[KEY_HOME KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_DOWN KEY_ENTER] +
            # Check tests statuses
            %w[KEY_HOME d KEY_ESCAPE]
        )
        expect_menu_items_to_include('[*] in_game_tests_suite - 3 / 4')
        expect_menu_items_to_include('[*] in_game_test_1 - ok - In-game test 1', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_2 - failed_ctd - In-game test 2', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_3 - ok - In-game test 3', menu_idx: -4)
        expect_menu_items_to_include('[*] in_game_test_4 - ok - In-game test 4', menu_idx: -4)
      end

    end

  end

end
