require 'English'
require 'curses_menu'
require 'modsvaskr/logger'
require 'modsvaskr/tests_runner'
require 'modsvaskr/run_cmd'
require 'modsvaskr/version'

module Modsvaskr

  # Main UI, using ncurses
  class Ui

    include RunCmd
    include Logger

    # Constructor
    #
    # Parameters::
    # * *config* (Config): Configuration object
    def initialize(config:)
      log "Launch Modsvaskr UI v#{Modsvaskr::VERSION} - Logs in #{Logger.log_file}"
      @config = config
    end

    # Run the UI
    def run
      last_modsvaskr_version = nil
      gem_list_stdout = `gem list modsvaskr --remote`
      gem_list_stdout.split("\n").each do |line|
        if line =~ /^modsvaskr \((.+?)\)/
          last_modsvaskr_version = Regexp.last_match(1)
          break
        end
      end
      log "!!! Could not get latest Modsvaskr version. Output of gem list modsvaskr --remote:\n#{gem_list_stdout}" if last_modsvaskr_version.nil?
      key_presses = @config.auto_keys.map do |key_str|
        case key_str
        when 'KEY_ENTER', 'KEY_ESCAPE'
          CursesMenu.const_get(key_str.to_sym)
        when /^KEY_\w+$/
          Curses.const_get(key_str.to_sym)
        else
          key_str
        end
      end
      CursesMenu.new(
        "Modsvaskr v#{Modsvaskr::VERSION} - Stronghold of Mods#{!last_modsvaskr_version.nil? && last_modsvaskr_version != Modsvaskr::VERSION ? " - !!! New version available: #{last_modsvaskr_version}" : ''}",
        key_presses:
      ) do |main_menu|
        @config.games.each do |game|
          main_menu.item "#{game.name} (#{game.path})" do
            CursesMenu.new(
              "Modsvaskr v#{Modsvaskr::VERSION} - Stronghold of Mods > #{game.name}",
              key_presses:
            ) do |game_menu|
              game_menu.item 'Testing' do
                # Read tests info
                tests_runner = TestsRunner.new(@config, game)
                # Selected test names, per test type
                # Hash< Symbol, Hash< String, nil > >
                selected_tests_suites = {}
                CursesMenu.new(
                  "Modsvaskr v#{Modsvaskr::VERSION} - Stronghold of Mods > #{game.name} > Testing",
                  key_presses:
                ) do |test_menu|
                  tests_runner.tests_suites.each do |tests_suite|
                    statuses_for_suite = tests_runner.statuses_for(tests_suite)
                    all_tests_selected = selected_tests_suites.key?(tests_suite) &&
                      selected_tests_suites[tests_suite].keys.sort == statuses_for_suite.map { |(test_name, _test_status)| test_name }.sort
                    test_menu.item(
                      "[#{
                          if all_tests_selected
                            '*'
                          elsif selected_tests_suites.key?(tests_suite)
                            '+'
                          else
                            ' '
                          end
                        }] #{tests_suite} - #{statuses_for_suite.select { |(_name, status)| status == 'ok' }.size} / #{statuses_for_suite.size}",
                      actions: {
                        'd' => {
                          name: 'Details',
                          execute: proc do
                            CursesMenu.new(
                              "Modsvaskr v#{Modsvaskr::VERSION} - Stronghold of Mods > #{game.name} > Testing > Tests #{tests_suite}",
                              key_presses:
                            ) do |tests_suite_menu|
                              statuses_for_suite.each do |(test_name, test_status)|
                                test_selected = selected_tests_suites.key?(tests_suite) && selected_tests_suites[tests_suite].key?(test_name)
                                tests_suite_menu.item "[#{test_selected ? '*' : ' '}] #{test_name} - #{test_status} - #{tests_runner.test_info(tests_suite, test_name)[:name]}" do
                                  if test_selected
                                    selected_tests_suites[tests_suite].delete(test_name)
                                    selected_tests_suites.delete(tests_suite) if selected_tests_suites[tests_suite].empty?
                                  else
                                    selected_tests_suites[tests_suite] = {} unless selected_tests_suites.key?(tests_suite)
                                    selected_tests_suites[tests_suite][test_name] = nil
                                  end
                                  :menu_refresh
                                end
                              end
                              tests_suite_menu.item 'Back' do
                                :menu_exit
                              end
                            end
                            :menu_refresh
                          end
                        }
                      }
                    ) do
                      if all_tests_selected
                        selected_tests_suites.delete(tests_suite)
                      else
                        selected_tests_suites[tests_suite] = statuses_for_suite.to_h { |(test_name, _test_status)| [test_name, nil] }
                      end
                      :menu_refresh
                    end
                  end
                  test_menu.item 'Select tests that are not ok' do
                    selected_tests_suites = {}
                    tests_runner.tests_suites.map do |tests_suite|
                      tests_not_ok = {}
                      tests_runner.statuses_for(tests_suite).each do |(test_name, test_status)|
                        tests_not_ok[test_name] = nil unless test_status == 'ok'
                      end
                      selected_tests_suites[tests_suite] = tests_not_ok unless tests_not_ok.empty?
                    end
                    :menu_refresh
                  end
                  test_menu.item 'Register tests from selected test suites' do
                    selected_tests_suites.each_key do |tests_suite|
                      tests_runner.set_statuses_for(
                        tests_suite,
                        (
                          tests_runner.discover_tests_for(tests_suite) -
                            tests_runner.statuses_for(tests_suite).map { |(test_name, _test_status)| test_name }
                        ).map { |test_name| [test_name, ''] }
                      )
                    end
                    :menu_refresh
                  end
                  test_menu.item 'Unregister tests from selected test suites' do
                    selected_tests_suites.each_key do |tests_suite|
                      tests_runner.clear_tests_for(tests_suite)
                    end
                    :menu_refresh
                  end
                  test_menu.item 'Clear selected test statuses' do
                    selected_tests_suites.each do |tests_suite, test_names_set|
                      tests_runner.set_statuses_for(tests_suite, test_names_set.keys.map { |test_name| [test_name, ''] })
                    end
                    :menu_refresh
                  end
                  test_menu.item 'Run remaining selected tests' do
                    tests_runner.run(
                      selected_tests_suites.map do |selected_tests_suite, selected_test_names_set|
                        [
                          selected_tests_suite,
                          # Make sure tests to be run are ordered from the registered list
                          tests_runner.
                            statuses_for(selected_tests_suite).map { |(test_name, _test_status)| test_name }.
                            select { |test_name| selected_test_names_set.key?(test_name) }
                        ]
                      end
                    )
                    :menu_refresh
                  end
                  test_menu.item 'Back' do
                    :menu_exit
                  end
                end
              end
              game.complete_game_menu(game_menu) if game.respond_to?(:complete_game_menu)
              game_menu.item 'Back' do
                :menu_exit
              end
            end
          end
        end
        main_menu.item 'See logs' do
          CursesMenu.new(
            'Modsvaskr - Stronghold of Mods > Logs',
            key_presses:
          ) do |logs_menu|
            File.read(Logger.log_file).split("\n").each do |line|
              logs_menu.item line
            end
            logs_menu.item 'Back' do
              :menu_exit
            end
          end
        end
        main_menu.item 'Quit' do
          :menu_exit
        end
      end
    rescue
      log "Unhandled exception: #{$ERROR_INFO}\n#{$ERROR_INFO.backtrace.join("\n")}"
      raise
    ensure
      log 'Close Modsvaskr UI'
    end

  end

end
