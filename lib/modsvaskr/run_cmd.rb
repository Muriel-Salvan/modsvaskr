module Modsvaskr

  module RunCmd

    # Run a given command with eventual parameters
    #
    # Parameters::
    # * *cmd* (Hash<Symbol,Object>): The command description:
    #   * *dir* (String): Directory in which the command is found
    #   * *exe* (String): Name of the executable of the command
    #   * *args* (Array<String>): Default arguments of the command [default = []]
    # * *args* (Array<String>): Additional arguments to give the command [default: []]
    def run_cmd(cmd, args: [])
      Dir.chdir cmd[:dir] do
        cmd_line = "\"#{cmd[:exe]}\" #{((cmd.key?(:args) ? cmd[:args] : []) + args).join(' ')}".strip
        raise "Unable to execute command line from \"#{cmd[:dir]}\": #{cmd_line}" unless system cmd_line
      end
    end

  end

end
