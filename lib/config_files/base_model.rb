module ConfigFiles
  # A base class for models. Represents a configuration file as an object
  # with domain-specific attributes/methods. For persistent storage,
  # use load and save,
  # Non-responsibilities: actual storage and parsing (both delegated).
  # There is no caching involved.
  class BaseModel
    # @param parser [.parse, .serialize] parser that can convert object to
    #   string and vice versa. It have to provide methods
    #   `string #serialize(object)` and `object #parse(string)`.
    #   For example see {ConfigFile::AugeasParser}
    # @param file_path [String] expected path passed to file_handler
    # @param file_handler [.read, .write] object, that can read/write string.
    #   It have to provide methods `string read(string)` and
    #   `write(string, string). For example see {ConfigFiles::MemoryFile}
    def initialize(parser, file_path, file_handler: File)
      @file_handler = file_handler
      @parser = parser
      @file_path = file_path
    end

    def save(changes_only: false)
      merge_changes if changes_only
      @file_handler.write(@file_path, @parser.serialize(data))
    end

    def load
      self.data = @parser.parse(@file_handler.read(@file_path))
    end

  protected

    attr_accessor :data

    def merge_changes
      new_data = data.dup
      read
      # TODO: recursive merge
      data.merge(new_data)
    end
  end
end
