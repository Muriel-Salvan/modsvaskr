require 'fileutils'
require 'logger'
require 'tmpdir'
require 'yaml'
require 'modsvaskr/config'
require 'modsvaskr/ui'

module ModsvaskrTest

  module Helpers

    # Are we in debug mode?
    #
    # Result::
    # * Boolean: Are we in debug mode?
    def self.debug?
      ENV['TEST_DEBUG'] == '1'
    end

    # Are we in debug mode?
    #
    # Result::
    # * Boolean: Are we in debug mode?
    def debug?
      ModsvaskrTest::Helpers.debug?
    end

    # Dump debug logs
    #
    # Parameters::
    # * *msg* (String): Message to debug
    def log_debug(msg)
      puts msg if debug?
    end

    # Create a temporary directory.
    # Delete the directory when exiting.
    #
    # Parameters::
    # * *name* (String): Name to be given to the directory
    # * Proc: Code called with dir created
    #   * Parameters::
    #     * *dir* (String): Directory that can be used
    def with_tmp_dir(name)
      dir = "#{Dir.tmpdir}/modsvaskr_test/#{name}"
      FileUtils.mkdir_p dir
      begin
        yield dir
      ensure
        FileUtils.rm_rf dir
      end
    end

    # Instantiate a Modsvaskr instance and play a given keys sequence.
    #
    # Parameters::
    # * *config* (Hash): The configuration to use [default: {}]
    # * *keys* (Array<String>): Keys to auto-run [default: []]
    # * *client_code* (Proc): Code called after run and before clean-up, or nil if none [default = nil]
    def run_modsvaskr(config: {}, keys: [], &client_code)
      @last_logs = nil
      config['auto_keys'] = @menu_enter_keys + keys + @menu_exit_keys
      config['auto_keys'] << 'KEY_ESCAPE' unless debug?
      config['no_prompt'] = !debug?
      with_tmp_dir('workspace') do |workspace_dir|
        Modsvaskr::Logger.stdout_io = Logger.new('/dev/null') unless debug?
        Modsvaskr::Logger.log_file = "#{workspace_dir}/modsvaskr_test.log"
        config_file = "#{workspace_dir}/modsvaskr.yaml"
        File.write(config_file, config.to_yaml)
        log_debug "Run Modsvaskr with test config:\n#{File.read(config_file)}\n"
        Modsvaskr::Ui.new(config: Modsvaskr::Config.new(config_file)).run
        @last_logs = File.read(Modsvaskr::Logger.log_file).split("\n")
        client_code&.call
      end
    end

    # Expect logs to include a given line
    #
    # Parameters::
    # * *line* (String or Regexp): Log line to look for
    def expect_logs_to_include(line)
      expect(@last_logs).not_to eq nil
      expect(@last_logs).to include(line), "Expected logs to include \"#{line}\" but got those:\n#{@last_logs.join("\n")}"
    end

    # Expect the a menu displayed (referenced by its index) to have a title including a given line
    #
    # Parameters::
    # * *line* (String or Regexp): Line to match against the menu title
    # * *menu_idx* (Integer or nil): Menu index on which the expectation has to be performed, or nil for the last one [default: @menu_index]
    def expect_menu_title_to_include(line, menu_idx: @menu_index)
      menu_idx = -1 if menu_idx.nil?
      expect(ModsvaskrTest.screenshots.size).to be > 0
      expect(ModsvaskrTest.screenshots[menu_idx][1]).to match line
    end

    # Expect the a menu displayed (referenced by its index) to have an item matching a given line
    #
    # Parameters::
    # * *line* (String or Regexp): Line to match against the menu items
    # * *menu_idx* (Integer or nil): Menu index on which the expectation has to be performed, or nil for the last one [default: @menu_index]
    def expect_menu_items_to_include(line, menu_idx: @menu_index)
      menu_idx = -1 if menu_idx.nil?
      expect(ModsvaskrTest.screenshots.size).to be > 0
      error_msg_proc = proc do
        <<~EO_ERROR_MESSAGE
          Expected menu ##{menu_idx} to have item "#{line}", but got this instead:
          #{
            ModsvaskrTest.screenshots[menu_idx][3..-3].map do |line|
              stripped_line = line.strip
              stripped_line.empty? ? nil : stripped_line
            end.compact.join("\n")
          }
        EO_ERROR_MESSAGE
      end
      if line.is_a?(Regexp)
        expect(ModsvaskrTest.screenshots[menu_idx][3..-3].any? { |menu_line| menu_line.match(line) }).to eq(true), error_msg_proc
      else
        expect(ModsvaskrTest.screenshots[menu_idx][3..-3].any? { |menu_line| menu_line.include?(line) }).to eq(true), error_msg_proc
      end
    end

    # Register the keys needed to enter the menu
    #
    # Parameters::
    # * *keys* (Array<String>): Keys sequence
    def entering_menu_keys(keys)
      @menu_enter_keys = keys
    end

    # Register the keys needed to exit the menu
    #
    # Parameters::
    # * *keys* (Array<String>): Keys sequence
    def exiting_menu_keys(keys)
      @menu_exit_keys = keys
    end

    # Register the default menu index to be tested
    #
    # Parameters::
    # * *menu_index* (Integer): The menu index
    def menu_index_to_test(menu_index)
      @menu_index = menu_index
    end

    # Mock a list of URLs with content from files
    #
    # Parameters::
    # * *mocks* (Hash<String, String>): File name per URL to be mocked
    def mock_web(mocks)
      mocks.each do |url, file|
        stub_request(:get, url).to_return(body: File.read("spec/modsvaskr_test/web_mocks/#{file}"))
      end
    end

    # Mock calls to system or `` methods, on any object, with an expected sequence
    #
    # Parameters::
    # * *expected_syscalls* (Array<[String or Regexp, Object]>): Ordered list of expected commands (or regexp matching command), and their corresponding mocking code.
    #   The mocking code can be:
    #   * Boolean: If true, then the command has succeeded. stdout and stderr are considered empty, and return code is 0. Useful to mock calls done using system.
    #   * String: Standard output of the command. When used, then the command is supposed to have succeeded and return code is 0. Useful to mock calls done using ``.
    #   * Proc: A code block that would be executed to get the mocked result:
    #     * Parameters::
    #       * *cmd* (String): The command to be executed
    #     * Result::
    #       * Object: One of the possible mocking results as defined above
    # * *add_init_mocks* (Boolean): If true, then automatically add init calls that are common [default: true]
    def mock_system_calls(expected_syscalls, add_init_mocks: true)
      if @remaining_expected_syscalls.nil?
        # First invocation for this test case
        @remaining_expected_syscalls = []
        @remaining_expected_syscalls << ['gem list modsvaskr --remote', "modsvaskr (#{Modsvaskr::VERSION})"] if add_init_mocks
        allow_any_instance_of(Object).to receive(:system) do |_receiver, cmd|
          mocked_result = expect_next_syscall(cmd)
          mocked_result[:exit_code] == 0
        end
        allow_any_instance_of(Object).to receive(:`) do |_receiver, cmd|
          mocked_result = expect_next_syscall(cmd)
          mocked_result[:stdout]
        end
      end
      @remaining_expected_syscalls.concat(expected_syscalls)
    end

    # Mock a temporary game directory.
    # Delete the directory when exiting
    #
    # Parameters::
    # * Proc: Code called with game dir setup
    #   * Parameters::
    #     * *game_dir* (String): Game directory that can be used
    def with_game_dir(&block)
      with_tmp_dir('game', &block)
    end

    # Add test game types in the configs created
    def add_test_game_types
      allow(Modsvaskr::Config).to receive(:new).and_wrap_original do |org_new, file|
        config = org_new.call(file)
        # Add test game plugins
        config.instance_eval do
          @game_types.merge!(
            Dir.glob("#{__dir__}/games/*.rb").map do |game_type_file|
              require game_type_file
              base_name = File.basename(game_type_file, '.rb')
              [
                base_name.to_sym,
                ModsvaskrTest::Games.const_get(base_name.split('_').collect(&:capitalize).join.to_sym)
              ]
            end.to_h
          )
        end
        config
      end
    end

    # Set tests plugins defined only for tests
    #
    # Parameters::
    # * *selected_tests_suites* (Array<Symbol> or nil): Tests that are available for tests, or nil for all tests [default = nil]
    def set_test_tests_suites(selected_tests_suites = nil)
      allow(Modsvaskr::TestsRunner).to receive(:new).and_wrap_original do |org_new, config, game|
        tests_runner = org_new.call(config, game)
        tests_runner.instance_exec do
          @tests_suites = @tests_suites.
            # First add tests suites defined in tests
            merge(Dir.glob("#{__dir__}/tests_suites/*.rb").map do |tests_suite_file|
              require tests_suite_file
              tests_suite = File.basename(tests_suite_file, '.rb').to_sym
              [
                tests_suite,
                ModsvaskrTest::TestsSuites.const_get(tests_suite.to_s.split('_').collect(&:capitalize).join.to_sym).new(tests_suite, game)
              ]
            end.to_h).
            # Then filter them if needed
            select { |tests_suite, _tests_suite_instance| selected_tests_suites.nil? || selected_tests_suites.include?(tests_suite) }
        end
        tests_runner
      end
    end

    # Mock an xEdit dump with a given CSV content
    #
    # Parameters::
    # * *csv* (String): The CSV content
    def mock_xedit_dump_with(csv)
      mock_system_calls [
        ['"SSEEdit.exe" -IKnowWhatImDoing -AllowMasterFilesEdit -SSE -autoload -script:"Modsvaskr_DumpInfo.pas"', proc do
          expect(File.exist?("#{@xedit_dir}/Edit Scripts/Modsvaskr_DumpInfo.pas")).to eq true
          # Mock the generation of the CSV
          File.write("#{@xedit_dir}/Edit Scripts/Modsvaskr_ExportedDumpInfo.csv", csv)
          true
        end]
      ]
    end

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
    # * *mock_tests_execution_stopped_by_user* (Boolean): If true, the mock an interruption done by the user [default: false]
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
      FileUtils.mkdir_p "#{@game_dir}/Data"
      autotest_esp = "#{@game_dir}/Data/AutoTest.esp"
      unless File.exist?(autotest_esp)
        # Create the AutoTest plugin
        expect(ElderScrollsPlugin).to receive(:new).with("#{@game_dir}/Data/AutoTest.esp") do
          mocked_esp = instance_double(ElderScrollsPlugin)
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
                          data: Base64.encode64(expect_tests.keys.map { |in_game_tests_suite| "AutoTest_Suite_#{in_game_tests_suite}" }.join('|'))
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
        File.write(autotest_esp, 'Fake AutoTest.esp')
      end
      # Create the AutoLoad plugin
      File.write("#{@game_dir}/Data/AutoLoad.cmd", 'Fake AutoLoad.cmd')
      # Expect in-game tests run to be setup and mock their run
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

    private

    # Expect a command to be the next expect4ed syscall and mock it.
    #
    # Parameters::
    # * *cmd* (String): Command being run
    # Result::
    # * Hash<Symbol, object>: Mocked result:
    #   * *exit_code* (Integer): The mocked exit code
    #   * *stdout* (String): The mocked stdout
    #   * *stderr* (String): The mocked stderr
    def expect_next_syscall(cmd)
      # Check that we were indeed expecting a command
      expected_cmd, mocked_syscall = @remaining_expected_syscalls.shift
      raise "No more system calls were expected, but received a call to system #{cmd}" if expected_cmd.nil?
      # Check that we wanted this particular command to be mocked
      raise "Expected system call #{expected_cmd}, but received a call to system #{cmd}" if (expected_cmd.is_a?(Regexp) && cmd !~ expected_cmd) || (expected_cmd.is_a?(String) && cmd != expected_cmd)

      # We're good. mock it.
      mocked_result = mocked_syscall.is_a?(Proc) ? mocked_syscall.call(cmd) : mocked_syscall
      result =
        if mocked_result.is_a?(String)
          {
            exit_code: 0,
            stdout: mocked_result,
            stderr: ''
          }
        else
          {
            exit_code: mocked_result ? 0 : 1,
            stdout: '',
            stderr: ''
          }
        end
      log_debug "[ #{Time.now.strftime('%F %T')} ] - Mock command #{cmd} => Exit code #{result[:exit_code]}#{result[:stdout].empty? ? '' : "\n----- STDOUT BEGIN:\n#{result[:stdout]}\n----- STDOUT END"}"
      result
    end

  end

end
