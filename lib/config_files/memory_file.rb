module ConfigFiles
  # memory file is used when string is stored only in memory.
  # Useful for testing. For remote read or socket read, own File class
  # creation is recommended.
  class MemoryFile
    attr_accessor :content

    def initialize(content = "")
      @content = content
    end

    def read(_path)
      @content.dup
    end

    def write(_path, content)
      @content = content
    end
  end
end
