module ModsvaskrTest

  module MockedModOrganizer

    class Download

      attr_reader :downloaded_file_path, :downloaded_date, :nexus_file_name, :nexus_mod_id, :nexus_file_id

      # Constructor
      #
      # Parameters::
      # * *downloaded_file_path* (String or nil): Full downloaded file path, or nil if does not exist [default: nil]
      # * *downloaded_date* (Time or nil): Download date of this source, or nil if no file [default: Time.now]
      # * *nexus_file_name* (String): Original file name from NexusMods [default: 'nexus_mods_file.7z']
      # * *nexus_mod_id* (Integer): Mod ID from NexusMods [default: 42]
      # * *nexus_file_id* (Integer): File ID from NexusMods [default: 666]
      def initialize(
        downloaded_file_path: nil,
        downloaded_date: Time.now,
        nexus_file_name: 'nexus_mods_file.7z',
        nexus_mod_id: 42,
        nexus_file_id: 666
      )
        @downloaded_file_path = downloaded_file_path
        @downloaded_date = downloaded_date
        @nexus_file_name = nexus_file_name
        @nexus_mod_id = nexus_mod_id
        @nexus_file_id = nexus_file_id
      end

    end

  end

end
