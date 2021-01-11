module Modsvaskr

  # Mixin adding logging functionality, both on screen and in file
  module Logger

    class << self
      attr_accessor :log_file
      attr_accessor :stdout_io
    end
    @log_file = File.expand_path('Modsvaskr.log')
    @stdout_io = $stdout

    # Log on screen and in log file
    #
    # Parameters::
    # * *msg* (String): Message to log
    def log(msg)
      complete_msg = "[ #{Time.now.strftime('%F %T')} ] - [ #{self.class.name.split('::').last} ] - #{msg}"
      Logger.stdout_io << "#{complete_msg}\n"
      File.open(Logger.log_file, 'a') do |f|
        f.puts complete_msg
      end
    end

    # Display an output to the user.
    # This is not a log.
    #
    # Parameters::
    # * *msg* (String): Message to output
    def out(msg)
      Logger.stdout_io << "#{msg}\n"
    end

    # Wait for the user to enter a line and hit Enter
    #
    # Result::
    # * String: The line entered by the user
    def wait_for_user_enter
      @config.no_prompt ? "\n" : $stdin.gets
    end

  end

end
