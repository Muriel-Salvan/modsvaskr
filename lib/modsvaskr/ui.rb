require 'English'
require 'curses_menu'
require 'launchy'
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
      @mod_organizer = @config.mod_organizer
    end

    # Time that should be before any file time of mods (used for sorting)
    TIME_BEGIN = Time.parse('2000-01-01')

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
        "Modsvaskr v#{Modsvaskr::VERSION} - Stronghold of Mods#{
          if !last_modsvaskr_version.nil? && last_modsvaskr_version != Modsvaskr::VERSION
            " - !!! New version available: #{last_modsvaskr_version}"
          else
            ''
          end
        }",
        key_presses:
      ) do |main_menu|
        @config.games.each do |game|
          main_menu.item "#{game.name} (#{game.path})" do
            CursesMenu.new(
              "Modsvaskr v#{Modsvaskr::VERSION} - Stronghold of Mods > #{game.name}",
              key_presses:
            ) do |game_menu|
              game_menu.item 'Plugins' do
                selected_esps = {}
                CursesMenu.new(
                  "Modsvaskr v#{Modsvaskr::VERSION} - Stronghold of Mods > #{game.name} > Plugins",
                  key_presses:
                ) do |plugins_menu|
                  game.load_order.each.with_index do |esp, idx|
                    plugins_menu.item "[#{selected_esps.key?(esp) ? '*' : ' '}] #{idx} - #{esp}" do
                      if selected_esps.key?(esp)
                        selected_esps.delete(esp)
                      else
                        selected_esps[esp] = nil
                      end
                      :menu_refresh
                    end
                  end
                  plugins_menu.item "Clean #{selected_esps.size} selected plugins" do
                    game.clean_plugins(selected_esps.keys)
                  end
                end
              end
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
        unless @mod_organizer.nil?
          main_menu.item 'Mods Organizer' do
            CursesMenu.new(
              'Modsvaskr - Stronghold of Mods > Mods Organizer',
              key_presses:
            ) do |mo_menu|
              # Show status
              mo_menu.item 'Run Mod Organizer' do
                @mod_organizer.run
              end
              mo_menu.item "#{@mod_organizer.mod_names.size} mods (#{@mod_organizer.mod_names.select { |mod_name| @mod_organizer.mod(name: mod_name).enabled? }.size} enabled)" do
                CursesMenu.new(
                  'Modsvaskr - Stronghold of Mods > Mods Organizer > Mods',
                  key_presses:
                ) do |mods_menu|
                  mod_names = @mod_organizer.mods_list
                  idx_size = (mod_names.size - 1).to_s.size
                  mod_names.each.with_index do |mod_name, idx|
                    mod = @mod_organizer.mod(name: mod_name)
                    # need_update = false
                    mods_menu.item(
                      proc do
                        sections = {
                          enabled_cell: {
                            text: mod.enabled? ? 'X' : ' ',
                            begin_with: '[',
                            end_with: ']',
                            fixed_size: 3
                          },
                          idx_cell: {
                            text: idx.to_s,
                            fixed_size: idx_size
                          },
                          name_cell: {
                            text: mod_name,
                            color_pair: CursesMenu::COLORS_GREEN,
                            fixed_size: 64
                          },
                          categories_cell: {
                            text: mod.categories.map { |category| "[#{category}]" }.join(' '),
                            fixed_size: 16
                          },
                          esps_cell: {
                            text: "#{mod.plugins.size} plugins",
                            fixed_size: 10
                          }
                        }
                        mod.sources.sort_by { |source| source.download.nil? ? TIME_BEGIN : source.download.downloaded_date }.each.with_index do |source, src_idx|
                          source_name = src_idx.zero? ? '' : '+ '
                          source_name <<
                            case source.type
                            when :nexus_mods
                              "Nexus Mod #{source.nexus_mod_id}/" +
                                if source.download&.nexus_file_name
                                  source.download&.nexus_file_name
                                elsif source.file_name
                                  source.file_name
                                else
                                  '<Unknown file>'
                                end
                            when :unknown
                              source.file_name || '<Unknown source>'
                            else
                              raise "Unknown source type: #{source.type} for #{mod.name}"
                            end
                          sections["source_#{src_idx}".to_sym] = {
                            text: source_name,
                            color_pair: CursesMenu::COLORS_WHITE
                          }
                        end
                        CursesMenu::CursesRow.new(sections)
                      end,
                      actions: proc do
                        actions = {}
                        # TODO: Use downloads' URL instead of mod's URL as it is very often more accurate
                        if mod.url
                          actions['v'] = {
                            name: 'Visit',
                            execute: proc { Launchy.open(mod.url) }
                          }
                        end
                        actions
                      end
                    )
                  end
                  mods_menu.item 'Back' do
                    :menu_exit
                  end
                end
              end
              mo_menu.item 'Back' do
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
