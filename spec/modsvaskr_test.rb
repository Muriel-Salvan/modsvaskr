require 'curses_menu'
require 'webmock/rspec'
require 'modsvaskr_test/helpers'
require 'modsvaskr_test/games/test_game'
require 'modsvaskr_test/tests_suites/in_game_tests_suite'
require 'modsvaskr_test/tests_suites/tests_suite'
require "#{Gem.loaded_specs['curses_menu'].full_gem_path}/spec/curses_menu_test.rb"

module ModsvaskrTest

  class << self

    # List of menu screenshots taken
    # Array< Array<String> >: List of screenshots (as lists of lines)
    attr_accessor :screenshots

  end

  # Monkey-patch the curses_menu_finalize method so that it captures the menu screen before finalizing
  module CursesMenuPatch

    # Finalize the curses menu window
    def curses_menu_finalize
      result = super
      ModsvaskrTest.screenshots << @screenshot.map { |line| line.map { |char_info| char_info[:char] }.join }
      puts ModsvaskrTest.screenshots.last.reject { |line| line.strip.empty? }.join("\n") if ModsvaskrTest::Helpers.debug?
      result
    end

  end

end

class CursesMenu

  prepend ModsvaskrTest::CursesMenuPatch

end

RSpec.configure do |config|
  config.include ModsvaskrTest::Helpers
  config.around do |example|
    # Initialize all variables to ensure tests independence
    ModsvaskrTest.screenshots = []
    ModsvaskrTest::Games::TestGame.init_proc = nil
    ModsvaskrTest::Games::TestGame.menu_proc = nil
    ModsvaskrTest::TestsSuites::TestsSuite.tests = {}
    ModsvaskrTest::TestsSuites::TestsSuite.mocked_statuses = {}
    ModsvaskrTest::TestsSuites::InGameTestsSuite.tests = {}
    ModsvaskrTest::TestsSuites::InGameTestsSuite.in_game_tests_for = nil
    ModsvaskrTest::TestsSuites::InGameTestsSuite.parse_auto_tests_statuses_for = nil
    @menu_enter_keys = []
    @menu_exit_keys = []
    @menu_index = nil
    @game_dir = nil
    @xedit_dir = nil
    @remaining_expected_syscalls = nil
    example.run
    expect(@remaining_expected_syscalls || []).to eq []
  end
  config.before do
    add_test_game_types
  end
end
