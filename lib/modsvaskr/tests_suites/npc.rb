module Modsvaskr

  module TestsSuites

    class Npc < TestsSuite

      # Discover the list of tests information that could be run.
      # [API] - This method is mandatory
      #
      # Result::
      # * Hash< String, Hash<Symbol,Object> >: Ordered hash of test information, per test name
      def discover_tests
        tests = {}
        @game.xedit.run_script('DumpInfo', only_once: true)
        CSV.read("#{@game.xedit.install_path}/Edit Scripts/Modsvaskr_ExportedDumpInfo.csv", encoding: 'windows-1251:utf-8').each do |row|
          tests["#{row[0].downcase}/#{row[2].to_i(16)}"] = {
            name: "Take screenshot of #{row[0]} - #{row[3]}"
          } if row[1].downcase == 'npc_'
        end
        tests
      end

      # Get the list of tests to be run in the AutoTest mod for a given list of test names.
      # AutoTest names are case insensitive.
      # [API] - This method is mandatory for tests needing to be run in-game.
      #
      # Parameters::
      # * *tests* (Array<String>): List of test names
      # Result::
      # * Hash<String, Array<String> >: List of AutoTest mod test names, per AutoTest mod tests suite
      def auto_tests_for(tests)
        { 'NPCs' => tests }
      end

      # Set statuses based on the result of AutoTest statuses.
      # AutoTest names are case insensitive.
      # [API] - This method is mandatory for tests needing to be run in-game.
      #
      # Parameters::
      # * *tests* (Array<String>): List of test names
      # * *auto_test_statuses* (Hash<String, Array<[String, String]> >): Ordered list of AutoTest [test name, test status], per AutoTest tests suite
      # Result::
      # * Array<[String, String]>: Corresponding list of [test name, test status]
      def parse_auto_tests_statuses_for(tests, auto_test_statuses)
        auto_test_statuses.key?('NPCs') ? auto_test_statuses['NPCs'] : []
      end

    end

  end

end
