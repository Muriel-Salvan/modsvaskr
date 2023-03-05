require 'modsvaskr_test/mocked_mod_organizer/download'

module ModsvaskrTest

  module MockedModOrganizer

    class Source

      attr_reader :nexus_mod_id, :nexus_file_id, :file_name, :type

      # Constructor
      #
      # Parameters::
      # * *type* (Symbol): Source type [default: :unknown]
      # * *nexus_mod_id* (Integer): Corresponding Nexus mod id [default: 42]
      # * *nexus_file_id* (Integer): Corresponding Nexus mod file id [default: 666]
      # * *file_name* (String or nil): File name that provided content to this mod [default: 'test_source_file.7z']
      # * *download* (Hash<Symbol, Object> or nil): The download info [default: nil]
      def initialize(
        type: :unknown,
        nexus_mod_id: 42,
        nexus_file_id: 666,
        file_name: 'test_source_file.7z',
        download: nil
      )
        @type = type
        @nexus_mod_id = nexus_mod_id
        @nexus_file_id = nexus_file_id
        @file_name = file_name
        @download = download
      end

      # Get the download info corresponding to this source, or nil if none.
      #
      # Result::
      # * Download or nil: Download info, or nil if none
      def download
        @download.nil? ? nil : Download.new(**@download)
      end

    end

  end

end
