require 'yaml'
require 'modsvaskr/logger'
require 'modsvaskr/run_cmd'

module Modsvaskr

  # Common functionality for any Game
  class Game

    include Logger, RunCmd

    # Constructor
    #
    # Parameters::
    # * *config* (Config): The config
    # * *game_info* (Hash<String,Object>): Game info:
    #   * *name* (String): Game name
    #   * *path* (String): Game installation dir
    #   * *launch_exe* (String): Executable to be launched
    #   * *min_launch_time_secs* (Integer): Minimum expected lauch time for the game, in seconds [default: 10]
    #   * *tests_poll_secs* (Integer): Interval in seconds to be respected between 2 test statuses polling [default: 5]
    #   * *timeout_frozen_tests_secs* (Integer): Timeout in seconds of a frozen game [default: 300]
    #   * *timeout_interrupt_tests_secs* (Integer): Timeout in seconds for the player to interrupt a tests session before restarting the game [default: 10]
    def initialize(config, game_info)
      @config = config
      # Set default values here
      @game_info = {
        'min_launch_time_secs' => 10,
        'tests_poll_secs' => 5,
        'timeout_frozen_tests_secs' => 300,
        'timeout_interrupt_tests_secs' => 10
      }.merge(game_info)
      @name = name
      @pid = nil
      init if self.respond_to?(:init)
    end

    # Return the game name
    #
    # Result::
    # * String: Game name
    def name
      @game_info['name']
    end

    # Return the game path
    #
    # Result::
    # * String: Game path
    def path
      @game_info['path']
    end

    # Return the launch executable
    #
    # Result::
    # * String: Launch executable
    def launch_exe
      @game_info['launch_exe']
    end

    # Return the tests polling interval
    #
    # Result::
    # * Integer: Tests polling interval
    def tests_poll_secs
      @game_info['tests_poll_secs']
    end

    # Return the timeout to detect a frozen game
    #
    # Result::
    # * Integer: Timeout to detect a frozen game
    def timeout_frozen_tests_secs
      @game_info['timeout_frozen_tests_secs']
    end

    # Return the timeout before restarting a game tests session
    #
    # Result::
    # * Integer: Timeout before restarting a game tests session
    def timeout_interrupt_tests_secs
      @game_info['timeout_interrupt_tests_secs']
    end

    # Return an xEdit instance for this game
    #
    # Result::
    # * Xedit: The xEdit instance
    def xedit
      @xedit = Xedit.new(@config.xedit_path, path) unless defined?(@xedit)
      @xedit
    end

    # Launch the game, and wait for launch to be successful
    #
    # Parameters::
    # * *autoload* (Boolean or String): If false, then launch the game using the normal launcher. If String, then use AutoLoad to load a given saved file (or empty to continue latest save) [default: false].
    def launch(autoload: false)
      # Launch the game
      @idx_launch = 0 unless defined?(@idx_launch)
      if autoload
        log "[ Game #{name} ] - Launch game (##{@idx_launch}) using AutoLoad #{autoload}..."
        autoload_file = "#{path}/Data/AutoLoad.cmd"
        if File.exist?(autoload_file)
          run_cmd({
            dir: path,
            exe: 'Data\AutoLoad.cmd',
            args: [autoload]
          })
        else
          log "[ Game #{name} ] - Missing file #{autoload_file}. Can't use AutoLoad to load game automatically. Please install the AutoLoad mod."
        end
      else
        log "[ Game #{name} ] - Launch game (##{@idx_launch}) using configured launcher (#{launch_exe})..."
        run_cmd({
          dir: path,
          exe: launch_exe
        })
      end
      @idx_launch += 1
      # The game launches asynchronously, so just wait a little bit and check for the process existence
      sleep @game_info['min_launch_time_secs']
      tasklist_stdout = nil
      loop do
        tasklist_stdout = `tasklist | find "#{running_exe}"`.strip
        break unless tasklist_stdout.empty?
        log "[ Game #{name} ] - #{running_exe} is not running. Wait for its startup..."
        sleep 1
      end
      @pid = Integer(tasklist_stdout.split(' ')[1])
      log "[ Game #{name} ] - #{running_exe} has started with PID #{@pid}"
    end

    # Is the game currently running?
    #
    # Result::
    # * Boolean: Is the game currently running?
    def running?
      if @pid
        running = true
        begin
          # Process.kill does not work when the game has crashed (the process is still detected as zombie)
          # running = Process.kill(0, @pid) == 1
          tasklist_stdout = `tasklist | find "#{running_exe}"`.strip
          running = !tasklist_stdout.empty?
          # log "[ Game #{name} ] - Tasklist returned no #{running_exe}:\n#{tasklist_stdout}" unless running
        rescue Errno::ESRCH
          log "[ Game #{name} ] - Got error while waiting for #{running_exe} PID #{@pid}: #{$!}"
          running = false
        end
        @pid = nil unless running
        running
      else
        false
      end
    end

    # Kill the game, and wait till it is killed
    def kill
      if @pid
        first_time = true
        while @pid do
          system "taskkill #{first_time ? '' : '/F '}/pid #{@pid}"
          first_time = false
          sleep 1
          if running?
            log "[ Game #{name} ] - #{running_exe} is still running (PID #{@pid}). Wait for its kill..."
            sleep 5
          end
        end
      else
        log "[ Game #{name} ] - Game not started, so nothing to kill."
      end
    end

  end

end
