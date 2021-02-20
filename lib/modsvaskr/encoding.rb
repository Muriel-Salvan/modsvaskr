module Modsvaskr

  module Encoding

    # Convert a string to UTF-8
    #
    # Parameters::
    # * *str* (String): The string to convert
    # Result::
    # * String: The converted string
    def self.to_utf8(str)
      orig_encoding = str.encoding
      encoding = nil
      begin
        encoding = %w[
          UTF-8
          Windows-1252
          ISO-8859-1
        ].find { |search_encoding| str.force_encoding(search_encoding).valid_encoding? }
      ensure
        str.force_encoding(orig_encoding)
      end
      raise "Unknown encoding for string #{str[0..127].inspect}" if encoding.nil?
      str.encode('UTF-8', encoding)
    end

  end

end
