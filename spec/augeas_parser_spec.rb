require_relative "spec_helper"
require "cfa/augeas_parser"

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
  end

  describe "#delete_if" do
    subject(:tree) { CFA::AugeasTree.new }

    before do
      tree.add("server", "127.127.1.0")
      tree.add("#comment[]", "this is a comment")
      tree.add("#comment[]", "other comment")
    end

    it "deletes entry that satisfies a condition" do
      tree.delete_if { |entry| entry[:value] == "127.127.1.0" }
      expect(tree["server"]).to eq nil
    end

    it "delete all entries that satisfy a condition" do
      tree.delete_if { |entry| entry[:key].include?("comment") }
      expect(tree.collection("#comment")).to be_empty
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
