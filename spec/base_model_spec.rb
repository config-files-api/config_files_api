require_relative "spec_helper"
require "cfa/augeas_parser"
require "cfa/base_model"
require "cfa/memory_file"

class TestModel < CFA::BaseModel
  PARSER = CFA::AugeasParser.new("postgresql.lns")
  PATH = "/var/lib/pgsql/postgresql.conf".freeze

  attributes(
    port: "port",
    lord: "lord"
  )

  def initialize(file_handler: nil)
    super(PARSER, PATH, file_handler: file_handler)
  end
end

# Most models will use the AugeasParser that we supply but we
# must not rely on that. Test with a non-standard parser.
class NonAugeasModel < CFA::BaseModel
  class Parser
    def parse(raw_string)
      raw_string.size
    end

    def serialize(data)
      "*" * data
    end

    def empty
      0
    end
  end

  def initialize(file_handler: nil)
    super(Parser.new, "/wherever", file_handler: file_handler)
  end
end

describe CFA::BaseModel do
  let(:handler) { nil }
  subject { TestModel.new(file_handler: handler) }

  describe ".default_file_handler" do
    it "returns object set by .default_file_handler" do
      memory_file = CFA::MemoryFile.new("")
      described_class.default_file_handler = memory_file
      expect(described_class.default_file_handler).to eq memory_file
    end

    it "returns File class if not set" do
      described_class.default_file_handler = nil
      expect(described_class.default_file_handler).to eq File
    end
  end

  describe ".default_file_handler=" do
    it "sets default_file_handler to given object" do
      memory_file = CFA::MemoryFile.new("")
      described_class.default_file_handler = memory_file
      expect(described_class.default_file_handler).to eq memory_file
    end
  end

  describe ".attributes" do
    let(:handler) do
      CFA::MemoryFile.new("port = 50 # need restart\nlord = 30\n")
    end

    before do
      subject.load
    end

    it "defines reader" do
      expect(subject.port).to eq "50"
      expect(subject.lord).to eq "30"
    end

    it "defines writer" do
      subject.port = "100"
      subject.lord = "10"
      subject.save
      expect(handler.content).to eq "port = 100 # need restart\nlord = 10\n"
    end
  end

  context "the parser does not provide #file_name= for error reporting" do
    let(:handler) { CFA::MemoryFile.new(".....") }
    subject { NonAugeasModel.new(file_handler: handler) }

    it "loads without crashing" do
      expect { subject.load }.to_not raise_error
    end

    it "saves without crashing" do
      expect { subject.save }.to_not raise_error
    end
  end
end
