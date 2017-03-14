require_relative "spec_helper"

require "cfa/augeas_parser"
require "cfa/augeas_parser/writer"
require "cfa/matcher"
require "cfa/placer"

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

    it "does not modify the string if not changed since parsing" do
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

  describe "#add" do
    it "adds the value where the placer creates it" do
      parser = CFA::AugeasParser.new("puppet.lns")
      file = "[main]\n# test1\n#test 2\n# test3\n"
      tree = parser.parse(file)

      matcher = CFA::Matcher.new(value_matcher: /test 2/)
      placer = CFA::ReplacePlacer.new(matcher)
      tree["main"].add("test", "data", placer)
      expect(parser.serialize(tree)).to eq(
        "[main]\n# test1\ntest=data\n#test3\n"
      )
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

describe CFA::AugeasWriter do
  describe "#write" do
    it "writes correctly all modification done on AugeasTree" do
      test_file = <<DOC
# comment1
# comment2
# comment3

[main]

test = lest
to_change = 1 # append comment
# comment 4
to_remove = 1
modified_trailing = 1 # traling to remove
space_for_trailing =1
DOC

      expected_output = <<DOC
# comment new
# comment3

[main]

test = lest
added=1
to_change = 0 # append comment
# comment 4
modified_trailing = 1
space_for_trailing =1#new trailing comment
[main2]
#new section
new_section=1
trailing_comment=1#new trailing comment
DOC

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(test_file)
      tree.delete(CFA::Matcher.new(value_matcher: /comment1/))
      matcher = CFA::Matcher.new(value_matcher: /comment2/)
      placer = CFA::BeforePlacer.new(matcher)
      tree.collection("#comment").add("comment new", placer)
      tree.collection("#comment").delete(/comment2/)
      subtree = tree["main"]
      subtree.delete("to_remove")
      subtree["to_change"].value = "0"
      placer = CFA::BeforePlacer.new(CFA::Matcher.new(key: "to_change"))
      subtree.add("added", "1", placer)
      subtree["modified_trailing"] = "1"
      subtree3 = CFA::AugeasTree.new
      subtree3["#comment"] = "new trailing comment"
      tree_value = CFA::AugeasTreeValue.new(subtree3, "1")
      subtree["space_for_trailing"] = tree_value

      # test also adding whole subtree
      subtree2 = CFA::AugeasTree.new
      comments = subtree2.collection("#comment")
      comments.add("new section")
      subtree2["new_section"] = "1"
      tree.add("main2", subtree2)
      subtree3 = CFA::AugeasTree.new
      subtree3["#comment"] = "new trailing comment"
      tree_value = CFA::AugeasTreeValue.new(subtree3, "1")
      subtree2["trailing_comment"] = tree_value

      expect(parser.serialize(tree)).to eq(expected_output)
    end
  end
end
