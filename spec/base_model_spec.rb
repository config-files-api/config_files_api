require_relative "spec_helper"
require "cfa/augeas_parser"
require "cfa/base_model"
require "cfa/memory_file"

# A testing model
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
  # Non-Augeas parser
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

describe CFA::BooleanValue do
  let(:name) { "my_bool" }
  let(:model) { TestModel.new }

  subject { described_class.new(name, model) }

  describe "#enabled?" do
    it "returns nil when unset" do
      expect(subject.enabled?).to be_nil
    end

    it "returns true when 'true'" do
      expect(subject).to receive(:data).and_return("true")
      expect(subject.enabled?).to eq(true)
    end

    it "returns false when 'false'" do
      expect(subject).to receive(:data).and_return("false")
      expect(subject.enabled?).to eq(false)
    end

    it "returns false when 'other'" do
      expect(subject).to receive(:data).and_return("other")
      expect(subject.enabled?).to eq(false)
    end
  end

  describe "#disabled?" do
    it "returns nil when unset" do
      expect(subject.disabled?).to be_nil
    end

    it "returns false when 'true'" do
      expect(subject).to receive(:data).and_return("true")
      expect(subject.disabled?).to eq(false)
    end

    it "returns true when 'false'" do
      expect(subject).to receive(:data).and_return("false")
      expect(subject.disabled?).to eq(true)
    end

    it "returns true when 'other'" do
      expect(subject).to receive(:data).and_return("other")
      expect(subject.disabled?).to eq(true)
    end
  end

  describe "#defined?" do
    it "returns false when unset" do
      expect(subject.defined?).to eq(false)
    end

    it "returns false when set" do
      expect(subject).to receive(:data).and_return("whatever")
      expect(subject.defined?).to eq(true)
    end
  end

  describe "#value=" do
    it "sets a true value" do
      subject.value = true
      expect(subject.enabled?).to eq(true)
    end

    it "sets a false value" do
      subject.value = false
      expect(subject.enabled?).to eq(false)
    end
  end

  describe "#enable" do
    it "sets a true value" do
      subject.enable
      expect(subject.enabled?).to eq(true)
    end
  end

  describe "#disable" do
    it "sets a false value" do
      subject.disable
      expect(subject.enabled?).to eq(false)
    end
  end

  describe "#inspect" do
    it "produces a nice description" do
      expect(subject.inspect)
        .to match(/#<
                   CFA::BooleanValue:0x.* \s
                   name=\"my_bool\", \s
                   data=nil, \s
                   true_value=\"true\", \s
                   false_value=\"false\"
                   >/x)
    end
  end
end
