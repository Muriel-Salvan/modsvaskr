require 'json'
require 'time'
require 'modsvaskr/tests_suite'

module Modsvaskr

  class TestsRunner

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
      # Parse tests suites
      @tests_suites = Hash[Dir.glob("#{__dir__}/tests_suites/*.rb").map do |tests_suite_file|
        tests_suite = File.basename(tests_suite_file, '.rb').to_sym
        require "#{__dir__}/tests_suites/#{tests_suite}.rb"
        [
          tests_suite,
          TestsSuites.const_get(tests_suite.to_s.split('_').collect(&:capitalize).join.to_sym).new(tests_suite, @game)
        ]
      end]
      @tests_info_file = "#{@game.path}/Data/Modsvaskr/Tests/TestsInfo.json"
    end

    # Return tests suites
    #
    # Result::
    # * Array<Symbol>: List of tests suites
    def tests_suites
      @tests_suites.keys
    end

    # Return test names for a given tests suite
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite
    # Result::
    # * Array<String>: Test names of this suite
    def discover_tests_for(tests_suite)
      discovered_tests = @tests_suites[tests_suite].discover_tests
      # Complete our tests information
      complete_info = tests_info
      discovered_tests.each do |test_name, test_info|
        complete_info[tests_suite] = {} unless complete_info.key?(tests_suite)
        complete_info[tests_suite][test_name] = test_info
      end
      update_tests_info(complete_info)
      discovered_tests.keys
    end

    # Get test statuses for a given tests suite
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite
    # Result::
    # * Array<[String, String]>: Ordered list of couples [test name, test status]
    def statuses_for(tests_suite)
      @tests_suites[tests_suite].statuses
    end

    # Set test statuses for a given tests suite
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite
    # * *statuses* (Array<[String, String]>): Ordered list of couples [test name, test status])
    def set_statuses_for(tests_suite, statuses)
      @tests_suites[tests_suite].set_statuses(statuses)
    end

    # Return test information
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite
    # * *test_name* (String): The test name
    # Result::
    # * Hash<Symbol,Object>: The test information (all properties are optional):
    #   * *name* (String): The test full name
    def test_info(tests_suite, test_name)
      tests_info.dig(tests_suite, test_name) || {}
    end

    # Clear tests for a given tests suite
    #
    # Parameters::
    # * *tests_suite* (Symbol): The tests suite
    def clear_tests_for(tests_suite)
      @tests_suites[tests_suite].clear_tests
    end

    # Run tests in a loop until they are all tested
    #
    # Parameters::
    # * *selected_tests* (Hash<Symbol, Array<String> >): Ordered list of tests to be run, per tests suite
    def run(selected_tests)
      # Test names (ordered) to be performed in game, per tests suite
      # Hash< Symbol, Array<String> >
      in_game_tests = {}
      selected_tests.each do |tests_suite, suite_selected_tests|
        if @tests_suites[tests_suite].respond_to?(:run_test)
          # Simple synchronous tests
          suite_selected_tests.each do |test_name|
            # Store statuses after each test just in case of crash
            set_statuses_for(tests_suite, [[test_name, @tests_suites[tests_suite].run_test(test_name)]])
          end
        end
        if @tests_suites[tests_suite].respond_to?(:auto_tests_for)
          # We run the tests from the game itself, using AutoTest mod.
          in_game_tests[tests_suite] = suite_selected_tests
        end
      end
      unless in_game_tests.empty?
        # Get the list of AutoTest we have to run and that we will monitor
        in_game_auto_tests = in_game_tests.inject({}) do |merged_auto_tests, (tests_suite, suite_selected_tests)|
          merged_auto_tests.merge(@tests_suites[tests_suite].auto_tests_for(suite_selected_tests)) do |auto_test_suite, auto_test_tests1, auto_test_tests2|
            (auto_test_tests1 + auto_test_tests2).uniq
          end
        end
        in_game_auto_tests.each do |auto_test_suite, auto_test_tests|
          # Write the JSON file that contains the list of tests to run
          File.write(
            "#{@game.path}/Data/SKSE/Plugins/StorageUtilData/AutoTest_#{auto_test_suite}_Run.json",
            JSON.pretty_generate(
              'stringList' => {
                'tests_to_run' => auto_test_tests
              }
            )
          )
          # Clear the AutoTest test statuses
          File.unlink("#{@game.path}/Data/SKSE/Plugins/StorageUtilData/AutoTest_#{auto_test_suite}_Statuses.json") if File.exist?("#{@game.path}/Data/SKSE/Plugins/StorageUtilData/AutoTest_#{auto_test_suite}_Statuses.json")
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
        puts ''
        puts '=========================================='
        puts '= In-game tests are about to be launched ='
        puts '=========================================='
        puts ''
        puts 'Here is what you need to do once the game will be launched (don\'t launch it by yourself, the test framework will launch it for you):'
        puts '* Load the game save you want to test (or start a new game).'
        puts ''
        puts 'This will execute all in-game tests automatically.'
        puts ''
        puts 'It is possible that the game crashes during tests:'
        puts '* That\'s a normal situation, as tests don\'t mimick a realistic gaming experience, and the Bethesda engine is not meant to be stressed like that.'
        puts '* In case of game crash (CTD), the Modsvaskr test framework will relaunch it automatically and resume testing from when it crashed.'
        puts '* In case of repeated CTD on the same test, the Modsvaskr test framework will detect it and skip the crashing test automatically.'
        puts '* In case of a game freeze without CTD, the Modsvaskr test framework will detect it after a few minutes and automatically kill the game before re-launching it to resume testing.'
        puts ''
        puts 'If you want to interrupt in-game testing: invoke the console with ~ key and type stop_tests followed by Enter.'
        puts ''
        puts 'Press enter to start in-game testing (this will lauch your game automatically)...'
        $stdin.gets
        idx_launch = 0
        old_statuses = auto_test_statuses
        loop do
          launch_game(use_autoload: idx_launch > 0)
          idx_launch += 1
          monitor_game_tests
          # Check tests again
          new_statuses = auto_test_statuses
          # Update the tests results based on what has been run in-game
          in_game_tests.each do |tests_suite, suite_selected_tests|
            @tests_suites[tests_suite].set_statuses(
              @tests_suites[tests_suite].
                parse_auto_tests_statuses_for(suite_selected_tests, new_statuses).
                select { |(test_name, _test_status)| suite_selected_tests.include?(test_name) }
            )
          end
          log 'Test statuses after game run:'
          print_test_statuses(new_statuses)
          # Careful as this JSON file can be written by Papyrus that treat strings as case insensitive.
          # cf. https://github.com/xanderdunn/skaar/wiki/Common-Tasks
          auto_test_config = Hash[JSON.parse(File.read(auto_test_config_file))['string'].map { |key, value| [key.downcase, value.downcase] }]
          if auto_test_config.dig('stopped_by') == 'user'
            log 'Tests have been stopped by user. Stop looping.'
            break
          end
          if auto_test_config.dig('tests_execution') == 'end'
            log 'Tests have finished running. Stop looping.'
            break
          end
          if new_statuses == old_statuses
            log 'No changes in AutoTest tests statuses in the game run. Stop looping.'
            break
          end
          old_statuses = new_statuses
          # We will start again. Leave some time to interrupt if we want.
          log 'We are going to start again in 10 seconds. Press Enter now to interrupt it.'
          key_pressed =
            begin
              Timeout.timeout(10) { $stdin.gets }
            rescue
              nil
            end
          if key_pressed
            log 'Run interrupted by user.'
            break
          end
        end
      end
    end

    private

    # Return all tests info.
    # Keep a cache of it.
    #
    # Result::
    # * Hash< Symbol, Hash< String, Hash<Symbol,Object> > >: The tests info, per test name, per tests suite
    def tests_info
      unless defined?(@tests_info_cache)
        @tests_info_cache =
          if File.exist?(@tests_info_file)
            Hash[JSON.parse(File.read(@tests_info_file)).map do |tests_suite_str, tests_suite_info|
              [
                tests_suite_str.to_sym,
                Hash[tests_suite_info.map { |test_name, test_info| [test_name, test_info.transform_keys(&:to_sym)] }]
              ]
            end]
          else
            {}
          end
      end
      @tests_info_cache
    end

    # Update tests info.
    #
    # Parameters::
    # * *tests_info* (Hash< Symbol, Hash< String, Hash<Symbol,Object> > >): The tests info, per test name, per tests suite
    def update_tests_info(tests_info)
      # Persist the tests information on disk
      FileUtils.mkdir_p File.dirname(@tests_info_file)
      File.write(@tests_info_file, JSON.pretty_generate(tests_info))
      @tests_info_cache = tests_info
    end

    # Launch the game, and wait for launch to be successful (get a PID)
    #
    # Parameters::
    # * *use_autoload* (Boolean): If true, then launch the game using AutoLoad
    def launch_game(use_autoload:)
      # Launch the game
      @idx_launch = 0 unless defined?(@idx_launch)
      Dir.chdir(@game.path) do
        if use_autoload
          log "Launch Game (##{@idx_launch}) using AutoLoad..."
          system "\"#{@game.path}/Data/AutoLoad.cmd\" auto_test"
        else
          log "Launch Game (##{@idx_launch}) using configured launcher..."
          system "\"#{@game.path}/#{@game.launch_exe}\""
        end
      end
      @idx_launch += 1
      # The game launches asynchronously, so just wait a little bit and check for the process
      sleep 10
      tasklist_stdout = nil
      loop do
        tasklist_stdout = `tasklist | find "#{@game.running_exe}"`.strip
        break unless tasklist_stdout.empty?
        log "#{@game.running_exe} is not running. Wait for its startup..."
        sleep 1
      end
      @game_pid = Integer(tasklist_stdout.split(' ')[1])
      log "#{@game.running_exe} has started with PID #{@game_pid}"
    end

    # Kill the game, and wait till it is killed
    def kill_game
      first_time = true
      loop do
        system "taskkill #{first_time ? '' : '/F'} /pid #{@game_pid}"
        first_time = false
        sleep 1
        tasklist_stdout = `tasklist | find "#{@game.running_exe}"`.strip
        break if tasklist_stdout.empty?
        log "#{@game.running_exe} is still running. Wait for its kill..."
        sleep 5
      end
    end

    # Get the list of AutoTest statuses
    #
    # Result::
    # * Hash<String, Array<[String, String]> >: Ordered list of AutoTest [test name, test status], per AutoTest tests suite
    def auto_test_statuses
      statuses = {}
      `dir "#{@game.path}/Data/SKSE/Plugins/StorageUtilData" /B`.split("\n").each do |file|
        if file =~ /^AutoTest_(.+)_Statuses\.json$/
          auto_test_suite = $1
          # Careful as this JSON file can be written by Papyrus that treat strings as case insensitive.
          # cf. https://github.com/xanderdunn/skaar/wiki/Common-Tasks
          statuses[auto_test_suite] = JSON.parse(File.read("#{@game.path}/Data/SKSE/Plugins/StorageUtilData/AutoTest_#{auto_test_suite}_Statuses.json"))['string'].map do |test_name, test_status|
            [test_name.downcase, test_status.downcase]
          end
        end
      end
      statuses
    end

    # Loop while monitoring game tests progression.
    # If the game exits, then exit also the loop.
    # In case no test is being updated for a long period of time, kill the game (we consider it was frozen)
    # Prerequisite: launch_game has to be called before.
    def monitor_game_tests
      log 'Start monitoring game testing...'
      last_time_tests_changed = Time.now
      # Get a picture of current tests
      current_statuses = auto_test_statuses
      loop do
        still_running = true
        begin
          # Process.kill does not work when the game has crashed (the process is still detected as zombie)
          # still_running = Process.kill(0, @game_pid) == 1
          tasklist_stdout = `tasklist 2>&1`
          still_running = tasklist_stdout.split("\n").any? { |line| line =~ /#{Regexp.escape(@game.running_exe)}/ }
          # log "Tasklist returned no Skyrim:\n#{tasklist_stdout}" unless still_running
        rescue Errno::ESRCH
          log "Got error while waiting for #{@game.running_exe} PID: #{$!}"
          still_running = false
        end
        # Log a diff in tests
        new_statuses = auto_test_statuses
        diff_statuses = diff_statuses(current_statuses, new_statuses)
        unless diff_statuses.empty?
          # Tests have progressed
          last_time_tests_changed = Time.now
          log '===== Test statuses changes:'
          diff_statuses.each do |tests_suite, tests_statuses|
            log "* #{tests_suite}:"
            tests_statuses.each do |(test_name, test_status)|
              log "  * #{test_name}: #{test_status}"
            end
          end
        end
        break unless still_running
        # If the tests haven't changed for too long, consider the game has frozen, but not crashed. So kill it.
        if Time.now - last_time_tests_changed > @timeout_frozen_tests_secs
          log "Last time test have changed is #{last_time_tests_changed.strftime('%F %T')}. Consider the game is frozen, so kill it."
          kill_game
          break
        end
        current_statuses = new_statuses
        sleep @tests_poll_secs
      end
      log 'End monitoring game testing.'
    end

    # Diff between test statuses.
    #
    # Parameters::
    # * *statuses1* (Hash<String, Array<[String, String]> >): Test statuses, per test name (in a sorted list), per tests suite
    # * *statuses2* (Hash<String, Array<[String, String]> >): Test statuses, per test name (in a sorted list), per tests suite
    # Result::
    # * Hash<String, Array<[String, String]> >: statuses2 - statuses1
    def diff_statuses(statuses1, statuses2)
      statuses = {}
      statuses1.each do |tests_suite, tests_info|
        if statuses2.key?(tests_suite)
          # Handle Hashes as it will be faster
          statuses1_for_test = Hash[tests_info]
          statuses2_for_test = Hash[statuses2[tests_suite]]
          statuses1_for_test.each do |test_name, status1|
            if statuses2_for_test.key?(test_name)
              if statuses2_for_test[test_name] != status1
                # Change in status
                statuses[tests_suite] = [] unless statuses.key?(tests_suite)
                statuses[tests_suite] << [test_name, statuses2_for_test[test_name]]
              end
            else
              # This test has been removed
              statuses[tests_suite] = [] unless statuses.key?(tests_suite)
              statuses[tests_suite] << [test_name, 'Deleted']
            end
          end
          statuses2_for_test.each do |test_name, status2|
            unless statuses1_for_test.key?(test_name)
              # This test has been added
              statuses[tests_suite] = [] unless statuses.key?(tests_suite)
              statuses[tests_suite] << [test_name, status2]
            end
          end
        else
          # All test statuses have been removed
          statuses[tests_suite] = tests_info.map { |(test_name, _test_status)| [test_name, 'Deleted'] }
        end
      end
      statuses2.each do |tests_suite, tests_info|
        # All test statuses have been added
        statuses[tests_suite] = tests_info unless statuses1.key?(tests_suite)
      end
      statuses
    end

    # Print test statuses
    #
    # Parameters::
    # * *statuses* (Hash<String, Array<[String, String]> >): Test statuses, per test name (in a sorted list), per tests suite
    def print_test_statuses(statuses)
      statuses.each do |tests_suite, statuses_for_type|
        next_test_name, _next_test_status = statuses_for_type.find { |(_name, status)| status != 'ok' }
        log "[ #{tests_suite} ] - #{statuses_for_type.select { |(_name, status)| status == 'ok' }.size} / #{statuses_for_type.size} - Next test to perform: #{next_test_name.nil? ? 'None' : next_test_name}"
      end
    end

  end

end
