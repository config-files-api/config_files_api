require_relative "spec_helper"
require "cfa/augeas_parser"
require "cfa/base_model"
require "cfa/memory_file"

describe CFA::BaseModel do
  let(:parser) { CFA::AugeasParser.new("sudoers.lns") }
  let(:path) { "/etc/sudoers" }
  subject { CFA::BaseModel.new(parser, path) }

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
end
