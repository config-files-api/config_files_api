# typed: strong
# frozen_string_literal: true

module CFA
  # memory file is used when string is stored only in memory.
  # Useful for testing. For remote read or socket read, own File class
  # creation is recommended.
  class MemoryFile
    sig {returns(String)}
    attr_accessor :content

    sig {params(content: T.untyped).void}
    def initialize(content = "")
    end

    sig {params(_path: T.untyped).returns(String)}
    def read(_path)
    end

    sig {params(_path: T.untyped, content: T.untyped).void}
    def write(_path, content)
    end
  end
end
