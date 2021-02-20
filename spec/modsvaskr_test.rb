require 'curses_menu'
require 'webmock/rspec'
require 'modsvaskr_test/helpers'
require 'modsvaskr_test/games/test_game'
require 'modsvaskr_test/tests_suites/in_game_tests_suite'
require 'modsvaskr_test/tests_suites/tests_suite'

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
      ModsvaskrTest.screenshots << capture_screenshot
      result = super
      puts ModsvaskrTest.screenshots.last.select { |line| !line.strip.empty? }.join("\n") if ModsvaskrTest::Helpers.debug?
      result
    end

    private

    # Get a screenshot of the menu
    #
    # Result::
    # * Array<String>: List of lines
    def capture_screenshot
      # Curses is initialized
      window = Curses.stdscr
      old_x = window.curx
      old_y = window.cury
      chars = []
      window.maxy.times do |idx_y|
        window.maxx.times do |idx_x|
          window.setpos idx_y, idx_x
          chars << window.inch
        end
      end
      window.setpos old_y, old_x
      chars.map(&:chr).each_slice(window.maxx).map(&:join)
    end

  end

end

class CursesMenu
  prepend ModsvaskrTest::CursesMenuPatch
end

RSpec.configure do |config|
  config.include ModsvaskrTest::Helpers
  config.around(:each) do |example|
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
    @remaining_expected_syscalls = nil
    example.run
    expect(@remaining_expected_syscalls || []).to eq []
  end
  config.before(:each) do
    add_test_game_types
  end
end
