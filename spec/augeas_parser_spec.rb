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
  let(:parser) { CFA::AugeasParser.new("puppet.lns") }
  let(:tree) { parser.parse(input_text) }
  let(:output_text) { parser.serialize(tree) }

  describe "#write" do
    context "for collections" do
      let(:input_text) do
        <<EOS
#comment1
#comment2
#comment3
EOS
      end

      it "deletes a collection item using a matcher" do
        tree.delete(CFA::Matcher.new(value_matcher: /comment1/))
        expect(output_text).to eq <<EOS
#comment2
#comment3
EOS
      end

      it "adds an item before another item" do
        matcher = CFA::Matcher.new(value_matcher: /comment2/)
        placer = CFA::BeforePlacer.new(matcher)
        tree.collection("#comment").add("comment new", placer)
        expect(output_text).to eq <<EOS
#comment1
#comment new
#comment2
#comment3
EOS
      end

      it "deletes a collection item using #collection" do
        tree.collection("#comment").delete(/comment2/)
        expect(output_text).to eq <<EOS
#comment1
#comment3
EOS
      end
    end

    context "for an existing subtree" do
      let(:input_text) do
        <<EOS
[main]
to_change = 1 # trailing comment
# comment 4
to_remove = 1
EOS
      end
      let(:subtree) { tree["main"] }

      it "deletes an item" do
        subtree.delete("to_remove")
        expect(output_text).to eq <<EOS
[main]
to_change = 1 # trailing comment
# comment 4
EOS
      end

      it "modifies the value of an AugeasTreeValue" do
        subtree["to_change"].value = "0"
        expect(output_text).to eq <<EOS
[main]
to_change = 0 # trailing comment
# comment 4
to_remove = 1
EOS
      end

      it "inserts an item" do
        placer = CFA::BeforePlacer.new(CFA::Matcher.new(key: "to_remove"))
        subtree.add("inserted", "1", placer)
        expect(output_text).to eq <<EOS
[main]
to_change = 1 # trailing comment
# comment 4
inserted=1
to_remove = 1
EOS
      end

      # WTF, it puts it at the end
      xit "inserts an item at the 1st position" do
        placer = CFA::BeforePlacer.new(CFA::Matcher.new(key: "to_change"))
        subtree.add("inserted", "1", placer)
        expect(output_text).to eq <<EOS
[main]
inserted = 1
to_change = 1 # trailing comment
# comment 4
to_remove = 1
EOS
      end

      # WTF, it puts it at the end
      xit "removes the tree of an AugeasTreeValue" do
        subtree["to_change"] = "0"
        expect(output_text).to eq <<EOS
[main]
to_change = 0
# comment 4
to_remove = 1
EOS
      end

      it "changes a value to an AugeasTreeValue" do
        subtree3 = CFA::AugeasTree.new
        subtree3["#comment"] = "new trailing comment"
        tree_value = CFA::AugeasTreeValue.new(subtree3, "2")
        subtree["to_remove"] = tree_value
        expect(output_text).to eq <<EOS
[main]
to_change = 1 # trailing comment
# comment 4
to_remove = 2#new trailing comment
EOS
      end
    end

    context "for a new subtree" do
      let(:input_text) do
        <<EOS
[existing]
unchanged = boring
EOS
      end
      let(:subtree) do
        subtree = CFA::AugeasTree.new
        tree.add("new", subtree)
        subtree
      end

      it "adds a collection" do
        comments = subtree.collection("#comment")
        comments.add("this is a new section")
        expect(output_text).to eq <<EOS
[existing]
unchanged = boring
[new]
#this is a new section
EOS
      end

      it "adds an item" do
        subtree["new_item"] = "1"
        expect(output_text).to eq <<EOS
[existing]
unchanged = boring
[new]
new_item=1
EOS
      end

      it "adds an AugeasTreeValue" do
        subtree3 = CFA::AugeasTree.new
        subtree3["#comment"] = "new trailing comment"
        tree_value = CFA::AugeasTreeValue.new(subtree3, "1")
        subtree["trailing_comment"] = tree_value
        expect(output_text).to eq <<EOS
[existing]
unchanged = boring
[new]
trailing_comment=1#new trailing comment
EOS
      end
    end

    it "writes entry which is added and then modified" do
      input = <<EOF
[main]
k1 = 1
EOF
      expected = <<EOF
[main]
k1 = 1
test=1
EOF

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      tree["main"].add("test", "0")
      tree["main"]["test"] = "1"

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "does not write entry which is added and then removed" do
      input = <<EOF
[main]
k1 = 1
# comment1
# comment2
EOF
      expected = <<EOF
[main]
k1 = 1
# comment1
# comment2
EOF

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      tree["main"].add("test", "0")
      tree["main"].delete("test")
      comments = tree["main"].collection("#comment")
      comments.add("temporary")
      comments.delete("temporary")

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "removes entry which is modified and then removed" do
      input = <<EOF
[main]
k1 = 1
EOF
      expected = <<EOF
[main]
EOF

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      tree["main"]["k1"] = "0"
      tree["main"].delete("k1")

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "modified entry, which is removed and then modified" do
      input = <<EOF
[main]
k1 = 1
EOF
      expected = <<EOF
[main]
k1 = 0
EOF

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      tree["main"].delete("k1")
      tree["main"]["k1"] = "0"

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "insert properly entry if it is in first position" do
      input = <<EOF
[main]
k1 = 1
EOF
      expected = <<EOF
[main]
t1=1
k1 = 1
EOF

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      matcher = CFA::Matcher.new(key: "k1")
      placer = CFA::BeforePlacer.new(matcher)
      tree["main"].add("t1", "1", placer)

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "writes entry if it is new one and others are removed" do
      input = <<EOF
[main]
k1 = 1
l1 = 1
EOF
      expected = <<EOF
[main]
t1=1
EOF

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      matcher = CFA::Matcher.new(key: "l")
      placer = CFA::BeforePlacer.new(matcher)
      tree["main"].add("t1", "1", placer)
      tree["main"].delete("k1")
      tree["main"].delete("l1")

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "writes in correct order several new entries" do
      input = <<EOF
[main]
k1 = 1
EOF
      expected = <<EOF
[main]
t1=1
t2=1
k1 = 1
t3=1
t4=1
EOF

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      matcher = CFA::Matcher.new(key: "k1")
      placer = CFA::BeforePlacer.new(matcher)
      tree["main"].add("t1", "1", placer)
      tree["main"].add("t2", "1", placer)
      matcher = CFA::Matcher.new(key: "k1")
      placer = CFA::AfterPlacer.new(matcher)
      tree["main"].add("t4", "1", placer)
      tree["main"].add("t3", "1", placer)

      expect(parser.serialize(tree)).to eq(expected)
    end
  end
end
