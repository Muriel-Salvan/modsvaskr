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
        client_code.call unless client_code.nil?
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
        <<~EOS
          Expected menu ##{menu_idx} to have item "#{line}", but got this instead:
          #{
            ModsvaskrTest.screenshots[menu_idx][3..-3].map do |line|
              stripped_line = line.strip
              stripped_line.empty? ? nil : stripped_line
            end.compact.join("\n")
          }
        EOS
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
    def with_game_dir
      with_tmp_dir('game') do |game_dir|
        yield game_dir
      end
    end

    # Add test game types in the configs created
    def add_test_game_types
      allow(Modsvaskr::Config).to receive(:new).and_wrap_original do |org_new, file|
        config = org_new.call(file)
        # Add test game plugins
        config.instance_eval do
          @game_types.merge!(Hash[
            Dir.glob("#{__dir__}/games/*.rb").map do |game_type_file|
              require game_type_file
              base_name = File.basename(game_type_file, '.rb')
              [
                base_name.to_sym,
                ModsvaskrTest::Games.const_get(base_name.split('_').collect(&:capitalize).join.to_sym)
              ]
            end
          ])
        end
        config
      end
    end

    # Add tests plugins defined only for tests
    def add_test_tests_suites
      allow(Modsvaskr::TestsRunner).to receive(:new).and_wrap_original do |org_new, config, game|
        tests_runner = org_new.call(config, game)
        tests_runner.instance_exec do
          @tests_suites = Hash[Dir.glob("#{__dir__}/tests_suites/*.rb").map do |tests_suite_file|
            require tests_suite_file
            tests_suite = File.basename(tests_suite_file, '.rb').to_sym
            [
              tests_suite,
              ModsvaskrTest::TestsSuites.const_get(tests_suite.to_s.split('_').collect(&:capitalize).join.to_sym).new(tests_suite, game)
            ]
          end]
        end
        tests_runner
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
      raise "Expected system call #{expected_cmd}, but received a call to system #{cmd}" if (expected_cmd.is_a?(Regexp) && !(cmd =~ expected_cmd)) || (expected_cmd.is_a?(String) && cmd != expected_cmd)
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
