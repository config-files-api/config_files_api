require_relative "spec_helper"
require "cfa/augeas_parser"
require "cfa/matcher"

def ntp_restrict_value(restrict_entry)
  entry = restrict_entry.split
  return "" if entry.empty?
  value = entry.first
  actions = entry[1..-1]
  return value if actions.empty?
  tree = CFA::AugeasTree.new
  actions.each { |a| tree.add("action[]", a) }
  CFA::AugeasTreeValue.new(tree, value)
end

describe CFA::AugeasParser do
  subject { described_class.new("sudoers.lns") }

  describe "#parse" do
    it "parses given string and returns AugeasTree instance" do
      example_file = "root ALL=(ALL) ALL\n"
      expect(subject.parse(example_file)).to be_a(CFA::AugeasTree)
    end

    it "can handle augeas with value and a tree below" do
      parser = CFA::AugeasParser.new("ntp.lns")
      tree = parser.parse(load_data("ntp.conf"))
      expect(tree["controlkey"].value).to eq "1"
      expect(tree["controlkey"].tree).to be_a CFA::AugeasTree
    end

    it "raises exception if augeas failed during parsing" do
      example_file = "invalid syntax\n"

      msg = /Augeas parsing\/serializing error/
      expect { subject.parse(example_file) }.to raise_error(msg)
    end
  end

  describe "#serialize" do
    it "creates text file from passed AugeasTree" do
      example_tree = CFA::AugeasTree.new
      example_tree["#comment[]"] = "test comment"
      expect(subject.serialize(example_tree)).to eq "# test comment\n"
    end

    xit "do not modify string if not changed from parse" do
      parser = CFA::AugeasParser.new("ntp.lns")
      data = load_data("ntp.conf")
      tree = parser.parse(data)
      expect(parser.serialize(tree)).to eq data
    end

    it "raises exception if passed tree cannot be converted by augeas lens" do
      example_tree = CFA::AugeasTree.new
      example_tree["invalid"] = "test"

      msg = /Augeas parsing\/serializing error/
      expect { subject.serialize(example_tree) }.to raise_error(msg)
    end
  end

  describe "#empty" do
    it "creates new empty AugeasTree" do
      expect(subject.empty).to be_a CFA::AugeasTree
    end
  end
end

describe CFA::AugeasTree do
  subject(:tree) do
    parser = CFA::AugeasParser.new("sudoers.lns")
    parser.parse(load_data("sudoers"))
  end

  describe "#collection" do
    it "returns AugeasCollection instace for given key" do
      expect(tree.collection("#comment")).to(
        be_a(CFA::AugeasCollection)
      )
    end
  end

  describe "#delete" do
    it "deletes given key from tree" do
      # lets use spec subtree as it use single value
      subtree = tree.collection("spec")[0]
      subtree.delete("user")
      expect(subtree["user"]).to eq nil
    end

    it "removes whole collection if collection key with '[]' is used" do
      tree.delete("#comment[]")
      expect(tree.collection("#comment")).to be_empty
    end

    it "removes objects using a matcher" do
      matcher = CFA::Matcher.new(collection: "#comment")
      tree.delete(matcher)
      expect(tree.collection("#comment")).to be_empty
    end

    it "does not remove anything is nil is passed" do
      size = tree.data.size
      tree.delete(nil)
      expect(tree.data.size).to eq(size)
    end
  end

  describe "#[]" do
    it "returns value for given key" do
      subtree = tree.collection("spec")[0]
      expect(subtree["user"]).to eq "ALL"
    end

    it "return first element in collection for collection name with '[]'" do
      expect(tree["#comment[]"]).to eq "# sudoers file."
    end

    it "returns nil if key do not exists" do
      expect(tree["nonexist"]).to eq nil
    end
  end

  describe "#[]=" do
    it "overwrites existing value with new one" do
      subtree = tree.collection("spec")[0]
      subtree["user"] = "tux"
      expect(subtree["user"]).to eq "tux"
    end

    it "adds new key with given value if key is not already used" do
      tree["new_cool_key"] = "Ever cooler value"
      expect(tree["new_cool_key"]).to eq "Ever cooler value"
    end
  end

  describe "#==" do
    let(:example_tree) do
      tree = CFA::AugeasTree.new
      tree.add("#comment", "sample comment")
      tree
    end

    it "returns true for equal trees" do
      other_tree = CFA::AugeasTree.new
      other_tree.add("#comment", "sample comment")
      expect(example_tree == example_tree.dup).to eq(true)
    end

    it "returns false for different trees" do
      other_tree = CFA::AugeasTree.new
      other_tree.add("server", "127.127.1.0")
      expect(example_tree == other_tree).to eq(false)
    end
  end
end

describe CFA::AugeasCollection do
  subject(:collection) do
    parser = CFA::AugeasParser.new(lens)
    tree = parser.parse(data)
    tree.collection(key)
  end

  describe "#delete (simple value)" do
    let(:lens) { "sudoers.lns" }
    let(:data) { load_data("sudoers") }
    let(:key) { "#comments" }

    it "removes from collection all elements matching parameter" do
      collection.delete(/visudo/)
      expect(collection.none? { |e| e =~ /visudo/ }).to eq true
    end
  end

  describe "#delete (complex value)" do
    let(:lens) { "ntp.lns" }
    let(:data) do
      "restrict -4 default notrap nomodify nopeer noquery\n" \
      "restrict -6 default notrap nomodify nopeer noquery\n"
    end
    let(:key) { "restrict" }

    it "removes from collection a complex value" do
      value = ntp_restrict_value("-4 default notrap nomodify nopeer noquery")
      collection.delete(value)
      expect(collection.none? { |e| e.value == "-4" }).to eq(true)
    end
  end
end
