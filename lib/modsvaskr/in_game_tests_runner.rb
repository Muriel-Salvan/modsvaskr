require 'base64'
require 'elder_scrolls_plugin'
require 'fileutils'
require 'json'
require 'time'
require 'timeout'
require 'modsvaskr/tests_suite'

module Modsvaskr

  # Class getting a simple API to handle tests that are run in-game
  class InGameTestsRunner

    include Logger

    # Constructor.
    # Default values are for a standard Skyrim SE installation.
    #
    # Parameters::
    # * *config* (Config): Main configuration
    # * *game* (Game): Game for which we run tests
    def initialize(config, game)
      @config = config
      @game = game
      auto_test_esp = "#{@game.path}/Data/AutoTest.esp"
      # Ordered list of available in-game test suites
      # Array<Symbol>
      @available_tests_suites =
        if File.exist?(auto_test_esp)
          Base64.decode64(
            ElderScrollsPlugin.new(auto_test_esp).
              to_json[:sub_chunks].
              find { |chunk| chunk[:decoded_header][:label] == 'QUST' }[:sub_chunks].
              find do |chunk|
                chunk[:sub_chunks].any? { |sub_chunk| sub_chunk[:name] == 'EDID' && sub_chunk[:data] =~ /AutoTest_ScriptsQuest/ }
              end[:sub_chunks].
              find { |chunk| chunk[:name] == 'VMAD' }[:data]
          ).scan(/AutoTest_Suite_(\w+)/).flatten.map { |tests_suite| tests_suite.downcase.to_sym }
        else
          log "[ In-game testing #{@game.name} ] - Missing file #{auto_test_esp}. In-game tests will be disabled. Please install the AutoTest mod."
          []
        end
      log "[ In-game testing #{@game.name} ] - #{@available_tests_suites.size} available in-game tests suites: #{@available_tests_suites.join(', ')}"
    end

    # Run in-game tests in a loop until they are all tested
    #
    # Parameters::
    # * *selected_tests* (Hash<Symbol, Array<String> >): Ordered list of in-game tests to be run, per in-game tests suite
    # * Proc: Code called when a in-game test status has changed
    #   * Parameters::
    #     * *in_game_tests_suite* (Symbol): The in-game tests suite for which test statuses have changed
    #     * *in_game_tests_statuses* (Hash<String,String>): Tests statuses, per test name
    def run(selected_tests)
      unknown_tests_suites = selected_tests.keys - @available_tests_suites
      log "[ In-game testing #{@game.name} ] - !!! The following in-game tests suites are not supported: #{unknown_tests_suites.join(', ')}" unless unknown_tests_suites.empty?
      tests_to_run = selected_tests.reject { |tests_suite, _tests| unknown_tests_suites.include?(tests_suite) }
      return if tests_to_run.empty?

      FileUtils.mkdir_p "#{@game.path}/Data/SKSE/Plugins/StorageUtilData"
      tests_to_run.each do |tests_suite, tests|
        # Write the JSON file that contains the list of tests to run
        File.write(
          "#{@game.path}/Data/SKSE/Plugins/StorageUtilData/AutoTest_#{tests_suite}_Run.json",
          JSON.pretty_generate(
            'stringList' => {
              'tests_to_run' => tests
            }
          )
        )
        # Clear the AutoTest test statuses that we are going to run
        statuses_file = "#{@game.path}/Data/SKSE/Plugins/StorageUtilData/AutoTest_#{tests_suite}_Statuses.json"
        next unless File.exist?(statuses_file)

        File.write(
          statuses_file,
          JSON.pretty_generate('string' => JSON.parse(File.read(statuses_file))['string'].delete_if { |test_name, _test_status| tests.include?(test_name) })
        )
      end
      auto_test_config_file = "#{@game.path}/Data/SKSE/Plugins/StorageUtilData/AutoTest_Config.json"
      # Write the JSON file that contains the configuration of the AutoTest tests runner
      File.write(
        auto_test_config_file,
        JSON.pretty_generate(
          'string' => {
            'on_start' => 'run',
            'on_stop' => 'exit'
          }
        )
      )
      out ''
      out '=========================================='
      out '= In-game tests are about to be launched ='
      out '=========================================='
      out ''
      out 'Here is what you need to do once the game will be launched (don\'t launch it by yourself, the test framework will launch it for you):'
      out '* Load the game save you want to test (or start a new game).'
      out ''
      out 'This will execute all in-game tests automatically.'
      out ''
      out 'It is possible that the game crashes during tests:'
      out '* That\'s a normal situation, as tests don\'t mimick a realistic gaming experience, and the Bethesda engine is not meant to be stressed like that.'
      out '* In case of game crash (CTD), the Modsvaskr test framework will relaunch it automatically and resume testing from when it crashed.'
      out '* In case of repeated CTD on the same test, the Modsvaskr test framework will detect it and skip the crashing test automatically.'
      out '* In case of a game freeze without CTD, the Modsvaskr test framework will detect it after a few minutes and automatically kill the game before re-launching it to resume testing.'
      out ''
      out 'If you want to interrupt in-game testing: invoke the console with ~ key and type stop_tests followed by Enter.'
      out ''
      out 'Press enter to start in-game testing (this will lauch your game automatically)...'
      wait_for_user_enter
      last_time_tests_changed = nil
      with_auto_test_monitoring(
        on_auto_test_statuses_diffs: proc do |in_game_tests_suite, in_game_tests_statuses|
          yield in_game_tests_suite, in_game_tests_statuses
          last_time_tests_changed = Time.now
        end
      ) do
        # Loop on (re-)launching the game when we still have tests to perform
        idx_launch = 0
        loop do
          # Check which test is supposed to run first, as it will help in knowing if it fails or not.
          first_tests_suite_to_run = nil
          first_test_to_run = nil
          current_tests_statuses = check_auto_test_statuses
          @available_tests_suites.each do |tests_suite|
            next unless tests_to_run.key?(tests_suite)

            found_test_ok =
              if current_tests_statuses.key?(tests_suite)
                # Find the first test that would be run (meaning the first one having no status, or status 'started')
                tests_to_run[tests_suite].find do |test_name|
                  found_test_name, found_test_status = current_tests_statuses[tests_suite].find { |(current_test_name, _current_test_status)| current_test_name == test_name }
                  found_test_name.nil? || found_test_status == 'started'
                end
              else
                # For sure the first test of this suite will be the first one to run
                tests_to_run[tests_suite].first
              end
            next unless found_test_ok

            first_tests_suite_to_run = tests_suite
            first_test_to_run = found_test_ok
            break
          end
          if first_tests_suite_to_run.nil?
            log "[ In-game testing #{@game.name} ] - No more test to be run."
            break
          else
            log "[ In-game testing #{@game.name} ] - First test to run should be #{first_tests_suite_to_run} / #{first_test_to_run}."
            # Launch the game to execute AutoTest
            @game.launch(autoload: idx_launch.zero? ? false : 'auto_test')
            idx_launch += 1
            log "[ In-game testing #{@game.name} ] - Start monitoring in-game testing..."
            last_time_tests_changed = Time.now
            while @game.running?
              check_auto_test_statuses
              # If the tests haven't changed for too long, consider the game has frozen, but not crashed. So kill it.
              if Time.now - last_time_tests_changed > @game.timeout_frozen_tests_secs
                log "[ In-game testing #{@game.name} ] - Last time in-game tests statuses have changed is #{last_time_tests_changed.strftime('%F %T')}. Consider the game is frozen, so kill it."
                @game.kill
              else
                sleep @game.tests_poll_secs
              end
            end
            last_test_statuses = check_auto_test_statuses
            # Log latest statuses
            log "[ In-game testing #{@game.name} ] - End monitoring in-game testing. In-game test statuses after game run:"
            last_test_statuses.each do |tests_suite, statuses_for_type|
              log "[ In-game testing #{@game.name} ] - [ #{tests_suite} ] - #{statuses_for_type.select { |(_name, status)| status == 'ok' }.size} / #{statuses_for_type.size}"
            end
            # Check for which reason the game has stopped, and eventually end the testing session.
            # Careful as this JSON file can be written by Papyrus that treat strings as case insensitive.
            # cf. https://github.com/xanderdunn/skaar/wiki/Common-Tasks
            auto_test_config = JSON.parse(File.read(auto_test_config_file))['string'].to_h { |key, value| [key.downcase, value.downcase] }
            if auto_test_config['stopped_by'] == 'user'
              log "[ In-game testing #{@game.name} ] - Tests have been stopped by user."
              break
            end
            if auto_test_config['tests_execution'] == 'end'
              log "[ In-game testing #{@game.name} ] - Tests have finished running."
              break
            end
            # From here we know that the game has either crashed or has been killed.
            # This is an abnormal termination of the game.
            # We have to know if this is due to a specific test that fails deterministically, or if it is the engine being unstable.
            # Check the status of the first test that should have been run to know about it.
            first_test_status = nil
            _found_test_name, first_test_status = last_test_statuses[first_tests_suite_to_run].find { |(current_test_name, _current_test_status)| current_test_name == first_test_to_run } if last_test_statuses.key?(first_tests_suite_to_run)
            if first_test_status == 'ok'
              # It's not necessarily deterministic.
              # We just have to go on executing next tests.
              log "[ In-game testing #{@game.name} ] - Tests session has finished in error, certainly due to the game's normal instability. Will resume testing."
            else
              # The first test doesn't pass.
              # We need to mark it as failed, then remove it from the runs.
              log "[ In-game testing #{@game.name} ] - First test #{first_tests_suite_to_run} / #{first_test_to_run} is in error status: #{first_test_status}. Consider it failed and skip it for next run."
              # If the test was started but failed before setting its status to something else then change the test status in the JSON file directly so that AutoTest does not try to re-run it.
              if first_test_status == 'started' || first_test_status == '' || first_test_status.nil?
                File.write(
                  "#{@game.path}/Data/SKSE/Plugins/StorageUtilData/AutoTest_#{first_tests_suite_to_run}_Statuses.json",
                  JSON.pretty_generate(
                    'string' => ((last_test_statuses[first_tests_suite_to_run] || []) + [[first_test_to_run, '']]).to_h do |(test_name, test_status)|
                      [
                        test_name,
                        test_name == first_test_to_run ? 'failed_ctd' : test_status
                      ]
                    end
                  )
                )
                # Notify the callbacks updating test statuses
                check_auto_test_statuses
              end
            end
            # We will start again. Leave some time to interrupt if we want.
            if @config.no_prompt
              out 'Start again automatically as no_prompt has been set.'
            else
              # First, flush stdin of any pending character
              $stdin.getc until select([$stdin], nil, nil, 2).nil?
              out "We are going to start again in #{@game.timeout_interrupt_tests_secs} seconds. Press Enter now to interrupt it."
              key_pressed =
                begin
                  Timeout.timeout(@game.timeout_interrupt_tests_secs) { $stdin.gets }
                rescue Timeout::Error
                  nil
                end
              if key_pressed
                log "[ In-game testing #{@game.name} ] - Run interrupted by user."
                # TODO: Remove AutoTest start on load: it has been interrupted by the user, so we should not keep it in case the user launches the game by itself.
                break
              end
            end
          end
        end
      end
    end

    private

    # Start an AutoTest monitoring session.
    # This allows checking for test statuses differences easily.
    #
    # Parameters::
    # * *on_auto_test_statuses_diffs* (Proc): Code called when a in-game test status has changed
    #   * Parameters::
    #     * *in_game_tests_suite* (Symbol): The in-game tests suite for which test statuses have changed
    #     * *in_game_tests_statuses* (Hash<String,String>): Tests statuses, per test name
    # * Proc: Code called with monitoring on
    def with_auto_test_monitoring(on_auto_test_statuses_diffs:)
      @last_auto_test_statuses = {}
      @on_auto_test_statuses_diffs = on_auto_test_statuses_diffs
      yield
    end

    # Check AutoTest test statuses differences, and call some code in case of changes in those statuses.
    # Remember the last checked statuses to only find diffs on next call.
    # Prerequisites: To be called inside a with_auto_test_monitoring block
    #
    # Result::
    # * Hash<Symbol, Array<[String, String]> >: Ordered list of AutoTest [test name, test status], per AutoTest tests suite
    def check_auto_test_statuses
      # Log a diff in tests
      new_statuses = auto_test_statuses
      diff_statuses = diff_statuses(@last_auto_test_statuses, new_statuses)
      unless diff_statuses.empty?
        # Tests have progressed
        log "[ In-game testing #{@game.name} ] - #{diff_statuses.size} tests suites have statuses changes:"
        diff_statuses.each do |tests_suite, tests_statuses|
          log "[ In-game testing #{@game.name} ]   * #{tests_suite}:"
          tests_statuses.each do |(test_name, test_status)|
            log "[ In-game testing #{@game.name} ]     * #{test_name}: #{test_status}"
          end
          @on_auto_test_statuses_diffs.call(tests_suite, tests_statuses.to_h)
        end
      end
      # Remember the current statuses
      @last_auto_test_statuses = new_statuses
      @last_auto_test_statuses
    end

    # Get the list of AutoTest statuses
    #
    # Result::
    # * Hash<Symbol, Array<[String, String]> >: Ordered list of AutoTest [test name, test status], per AutoTest tests suite
    def auto_test_statuses
      statuses = {}
      `dir "#{@game.path}/Data/SKSE/Plugins/StorageUtilData" /B`.split("\n").each do |file|
        next unless file =~ /^AutoTest_(.+)_Statuses\.json$/

        auto_test_suite = Regexp.last_match(1).downcase.to_sym
        # Careful as this JSON file can be written by Papyrus that treat strings as case insensitive.
        # cf. https://github.com/xanderdunn/skaar/wiki/Common-Tasks
        statuses[auto_test_suite] = JSON.parse(File.read("#{@game.path}/Data/SKSE/Plugins/StorageUtilData/#{file}"))['string'].map do |test_name, test_status|
          [test_name.downcase, test_status.downcase]
        end
      end
      statuses
    end

    # Diff between test statuses.
    #
    # Parameters::
    # * *statuses_1* (Hash<Symbol, Array<[String, String]> >): Test statuses, per test name (in a sorted list), per tests suite
    # * *statuses_2* (Hash<Symbol, Array<[String, String]> >): Test statuses, per test name (in a sorted list), per tests suite
    # Result::
    # * Hash<Symbol, Array<[String, String]> >: statuses_2 - statuses_1
    def diff_statuses(statuses_1, statuses_2)
      statuses = {}
      statuses_1.each do |tests_suite, tests_info|
        if statuses_2.key?(tests_suite)
          # Handle Hashes as it will be faster
          statuses_1_for_test = tests_info.to_h
          statuses_2_for_test = (statuses_2[tests_suite]).to_h
          statuses_1_for_test.each do |test_name, status_1|
            if statuses_2_for_test.key?(test_name)
              if statuses_2_for_test[test_name] != status_1
                # Change in status
                statuses[tests_suite] = [] unless statuses.key?(tests_suite)
                statuses[tests_suite] << [test_name, statuses_2_for_test[test_name]]
              end
            else
              # This test has been removed
              statuses[tests_suite] = [] unless statuses.key?(tests_suite)
              statuses[tests_suite] << [test_name, 'deleted']
            end
          end
          statuses_2_for_test.each do |test_name, status_2|
            next if statuses_1_for_test.key?(test_name)

            # This test has been added
            statuses[tests_suite] = [] unless statuses.key?(tests_suite)
            statuses[tests_suite] << [test_name, status_2]
          end
        else
          # All test statuses have been removed
          statuses[tests_suite] = tests_info.map { |(test_name, _test_status)| [test_name, 'deleted'] }
        end
      end
      statuses_2.each do |tests_suite, tests_info|
        # All test statuses have been added
        statuses[tests_suite] = tests_info unless statuses_1.key?(tests_suite)
      end
      statuses
    end

  end

end
