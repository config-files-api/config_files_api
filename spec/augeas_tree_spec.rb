require_relative "spec_helper"

require "cfa/augeas_parser"
require "cfa/matcher"
require "cfa/placer"

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
