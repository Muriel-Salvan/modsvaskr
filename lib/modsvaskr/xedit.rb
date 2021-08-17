require 'csv'
require 'modsvaskr/encoding'
require 'modsvaskr/run_cmd'

module Modsvaskr

  # Helper to use an instance of xEdit
  class Xedit

    include RunCmd

    # String: Installation path
    attr_reader :install_path

    # Constructor
    #
    # Parameters::
    # * *install_path* (String): Installation path of xEdit
    # * *game_path* (String): Installation path of the game to use xEdit on
    def initialize(install_path, game_path)
      @install_path = install_path
      @game_path = game_path
      # Set of scripts that have been run
      @runs = {}
    end

    # Run an xEdit script
    #
    # Parameters::
    # * *script* (String): Script name, as defined in xedit_scripts (without the Modsvaskr_ prefix and .pas suffix)
    # * *only_once* (Boolean): If true, then make sure this script is run only once by instance [default: false]
    def run_script(script, only_once: false)
      return if only_once && @runs.key?(script)

      FileUtils.cp "#{__dir__}/../../xedit_scripts/Modsvaskr_#{script}.pas", "#{@install_path}/Edit Scripts/Modsvaskr_#{script}.pas"
      run_cmd(
        {
          dir: @install_path,
          exe: 'SSEEdit.exe'
        },
        args: %W[
          -IKnowWhatImDoing
          -AllowMasterFilesEdit
          -SSE
          -autoload
          -script:"Modsvaskr_#{script}.pas"
        ]
      )
      @runs[script] = nil
    end

    # Parse a CSV that has been dumped by a previous run of xEdit
    #
    # Parameters::
    # * *csv* (String): Name of the CSV file (from Edit Scripts), without .csv
    # * *row_block* (Proc): Code called for each CSV row
    #   Parameters::
    #   * *row* (Array<String>): CSV row
    def parse_csv(csv, &row_block)
      CSV.parse(Encoding.to_utf_8(File.read("#{install_path}/Edit Scripts/#{csv}.csv", mode: 'rb'))).each(&row_block)
    end

  end

end
