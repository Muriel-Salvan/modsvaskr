module Modsvaskr

  # Mixin adding logging functionality, both on screen and in file
  module Logger

    class << self
      attr_accessor :log_file
    end
    @log_file = File.expand_path('Modsvaskr.log')

    # Log on screen and in log file
    #
    # Parameters::
    # * *msg* (String): Message to log
    def log(msg)
      complete_msg = "[ #{Time.now.strftime('%F %T')} ] - #{msg}"
      puts complete_msg
      File.open(Logger.log_file, 'a') do |f|
        f.puts complete_msg
      end
    end

  end

end
