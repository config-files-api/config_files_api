require_relative "spec_helper"
require "cfa/augeas_parser"

describe CFA::AugeasParser do
  subject { described_class.new("sudoers.lns") }

  describe "#parse" do
    it "parses given string and returns AugeasTree instance" do
      example_file = "root ALL=(ALL) ALL\n"
      expect(subject.parse(example_file)).to be_a(CFA::AugeasTree)
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
    parser = CFA::AugeasParser.new("sudoers.lns")
    tree = parser.parse(load_data("sudoers"))
    tree.collection("#comment")
  end

  describe "#delete" do
    it "removes from collection all elements matching parameter" do
      collection.delete(/visudo/)
      expect(collection.none? { |e| e =~ /visudo/ }).to eq true
    end
  end
end
