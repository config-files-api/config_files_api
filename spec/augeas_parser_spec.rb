require_relative "spec_helper"

require "cfa/augeas_parser"

describe CFA::AugeasParser do
  subject { described_class.new("sudoers.lns") }

  describe "#parse" do
    it "parses given string and returns AugeasTree instance" do
      example_file = "root ALL=(ALL) ALL\n"
      expect(subject.parse(example_file)).to be_a(CFA::AugeasTree)
    end

    it "does not fail if there is no trailing newline" do
      example_file = "root ALL=(ALL) ALL"
      expect(subject.parse(example_file)).to be_a(CFA::AugeasTree)
    end

    it "can handle augeas with value and a tree below" do
      parser = CFA::AugeasParser.new("ntp.lns")
      tree = parser.parse(load_data("ntp.conf"))
      expect(tree["controlkey"].value).to eq "1"
      expect(tree["controlkey"].tree).to be_a CFA::AugeasTree
    end

    it "raises exception if augeas failed during parsing" do
      example_file = "root ALL=(ALL) ALL\ninvalid syntax\n"
      subject.file_name = "/dev/garbage"

      # character possition depends on augeas version
      msg = /Augeas parsing error: .* at \/dev\/garbage:2:[08]/
      expect { subject.parse(example_file) }.to raise_error(msg)
    end

    it "raises exception if augeas lens failed" do
      example_file = "root ALL=(ALL) ALL\n"
      bad_parser = described_class.new("nosuchlens.lns")

      msg = /Augeas error: .* Details:/
      expect { bad_parser.parse(example_file) }.to raise_error(msg)
    end
  end

  describe "#serialize" do
    it "creates text file from passed AugeasTree" do
      example_tree = CFA::AugeasTree.new
      example_tree["#comment[]"] = "test comment"
      expect(subject.serialize(example_tree)).to eq "# test comment\n"
    end

    it "does not modify the string if not changed since parsing" do
      parser = CFA::AugeasParser.new("ntp.lns")
      data = load_data("ntp.conf")
      tree = parser.parse(data)
      expect(parser.serialize(tree)).to eq data
    end

    it "raises exception if passed tree cannot be converted by augeas lens" do
      example_tree = CFA::AugeasTree.new
      example_tree["invalid"] = "test"
      subject.file_name = "/etc/sudoers"

      msg = /Augeas serializing error: .* at \/etc\/sudoers::/m
      expect { subject.serialize(example_tree) }
        .to raise_error(msg)
    end
  end

  describe "#empty" do
    it "creates new empty AugeasTree" do
      expect(subject.empty).to be_a CFA::AugeasTree
    end
  end
end
