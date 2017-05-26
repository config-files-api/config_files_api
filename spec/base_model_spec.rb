require_relative "spec_helper"
require "cfa/augeas_parser"
require "cfa/base_model"
require "cfa/memory_file"

class TestModel < CFA::BaseModel
  PARSER = CFA::AugeasParser.new("postgresql.lns")
  PATH = "/var/lib/pgsql/postgresql.conf".freeze

  attributes(
    port: "port"
  )

  def initialize(file_handler: nil)
    super(PARSER, PATH, file_handler: file_handler)
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
    let(:handler) { CFA::MemoryFile.new("port = 50 # need restart\n") }

    before do
      subject.load
    end

    it "defines reader" do
      expect(subject.port).to eq "50"
    end

    it "defines writer" do
      subject.port = "100"
      subject.save
      expect(handler.content).to eq "port = 100 # need restart\n"
    end
  end
end
