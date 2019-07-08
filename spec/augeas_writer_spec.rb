# frozen_string_literal: true

require_relative "spec_helper"

require "cfa/augeas_parser"
require "cfa/augeas_parser/writer"
require "cfa/matcher"
require "cfa/placer"

describe CFA::AugeasWriter do
  let(:parser) { CFA::AugeasParser.new("puppet.lns") }
  let(:tree) { parser.parse(input_text) }
  let(:output_text) { parser.serialize(tree) }

  describe "#write" do
    context "for collections" do
      let(:input_text) do
        <<EXAMPLE
#comment1
#comment2
#comment3
EXAMPLE
      end

      it "deletes a collection item using a matcher" do
        tree.delete(CFA::Matcher.new(value_matcher: /comment1/))
        expect(output_text).to eq <<EXAMPLE
#comment2
#comment3
EXAMPLE
      end

      it "adds an item before another item" do
        matcher = CFA::Matcher.new(value_matcher: /comment2/)
        placer = CFA::BeforePlacer.new(matcher)
        tree.collection("#comment").add("comment new", placer)
        expect(output_text).to eq <<EXAMPLE
#comment1
#comment new
#comment2
#comment3
EXAMPLE
      end

      it "deletes a collection item using #collection" do
        tree.collection("#comment").delete(/comment2/)
        expect(output_text).to eq <<EXAMPLE
#comment1
#comment3
EXAMPLE
      end
    end

    context "for an existing subtree" do
      let(:input_text) do
        <<EXAMPLE
[main]
to_change = 1 # trailing comment
# comment 4
to_remove = 1
EXAMPLE
      end
      let(:subtree) { tree["main"] }

      it "deletes an item" do
        subtree.delete("to_remove")
        expect(output_text).to eq <<EXAMPLE
[main]
to_change = 1 # trailing comment
# comment 4
EXAMPLE
      end

      it "modifies the value of an AugeasTreeValue" do
        subtree["to_change"].value = "0"
        expect(output_text).to eq <<EXAMPLE
[main]
to_change = 0 # trailing comment
# comment 4
to_remove = 1
EXAMPLE
      end

      it "inserts an item" do
        placer = CFA::BeforePlacer.new(CFA::Matcher.new(key: "to_remove"))
        subtree.add("inserted", "1", placer)
        expect(output_text).to eq <<EXAMPLE
[main]
to_change = 1 # trailing comment
# comment 4
inserted=1
to_remove = 1
EXAMPLE
      end

      it "inserts an item at the 1st position" do
        placer = CFA::BeforePlacer.new(CFA::Matcher.new(key: "to_change"))
        subtree.add("inserted", "1", placer)
        expect(output_text).to eq <<EXAMPLE
[main]
inserted=1
to_change = 1 # trailing comment
# comment 4
to_remove = 1
EXAMPLE
      end

      it "removes the tree of an AugeasTreeValue" do
        subtree["to_change"] = "0"
        expect(output_text).to eq <<EXAMPLE
[main]
to_change = 0
# comment 4
to_remove = 1
EXAMPLE
      end

      it "changes a value to an AugeasTreeValue" do
        subtree3 = CFA::AugeasTree.new
        subtree3["#comment"] = "new trailing comment"
        tree_value = CFA::AugeasTreeValue.new(subtree3, "2")
        subtree["to_remove"] = tree_value
        expect(output_text).to eq <<EXAMPLE
[main]
to_change = 1 # trailing comment
# comment 4
to_remove = 2#new trailing comment
EXAMPLE
      end
    end

    context "for a new subtree" do
      let(:input_text) do
        <<EXAMPLE
[existing]
unchanged = boring
EXAMPLE
      end
      let(:subtree) do
        subtree = CFA::AugeasTree.new
        tree.add("new", subtree)
        subtree
      end

      it "adds a collection" do
        comments = subtree.collection("#comment")
        comments.add("this is a new section")
        expect(output_text).to eq <<EXAMPLE
[existing]
unchanged = boring
[new]
#this is a new section
EXAMPLE
      end

      it "adds an item" do
        subtree["new_item"] = "1"
        expect(output_text).to eq <<EXAMPLE
[existing]
unchanged = boring
[new]
new_item=1
EXAMPLE
      end

      it "adds an AugeasTreeValue" do
        subtree3 = CFA::AugeasTree.new
        subtree3["#comment"] = "new trailing comment"
        tree_value = CFA::AugeasTreeValue.new(subtree3, "1")
        subtree["trailing_comment"] = tree_value
        expect(output_text).to eq <<EXAMPLE
[existing]
unchanged = boring
[new]
trailing_comment=1#new trailing comment
EXAMPLE
      end
    end

    it "writes entry which is added and then modified" do
      input = <<EXAMPLE
[main]
k1 = 1
EXAMPLE
      expected = <<EXAMPLE
[main]
k1 = 1
test=1
EXAMPLE

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      tree["main"].add("test", "0")
      tree["main"]["test"] = "1"

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "does not write entry which is added and then removed" do
      input = <<EXAMPLE
[main]
k1 = 1
# comment1
# comment2
EXAMPLE
      expected = <<EXAMPLE
[main]
k1 = 1
# comment1
# comment2
EXAMPLE

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
      input = <<EXAMPLE
[main]
k1 = 1
EXAMPLE
      expected = <<EXAMPLE
[main]
EXAMPLE

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      tree["main"]["k1"] = "0"
      tree["main"].delete("k1")

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "modified entry, which is removed and then modified" do
      input = <<EXAMPLE
[main]
k1 = 1
EXAMPLE
      expected = <<EXAMPLE
[main]
k1 = 0
EXAMPLE

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      tree["main"].delete("k1")
      tree["main"]["k1"] = "0"

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "insert properly entry if it is in first position" do
      input = <<EXAMPLE
[main]
k1 = 1
EXAMPLE
      expected = <<EXAMPLE
[main]
t1=1
k1 = 1
EXAMPLE

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      matcher = CFA::Matcher.new(key: "k1")
      placer = CFA::BeforePlacer.new(matcher)
      tree["main"].add("t1", "1", placer)

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "writes entry if it is new one and others are removed" do
      input = <<EXAMPLE
[main]
k1 = 1
l1 = 1
EXAMPLE
      expected = <<EXAMPLE
[main]
t1=1
EXAMPLE

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
      input = <<EXAMPLE
[main]
k1 = 1
EXAMPLE
      expected = <<EXAMPLE
[main]
t1=1
t2=1
k1 = 1
t3=1
t4=1
EXAMPLE

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

    it "properly writes two following new trees" do
      input = <<EXAMPLE
[main]
t1 = 1
EXAMPLE
      expected = <<EXAMPLE
[main]
t1 = 1
[main2]
t1=2
[main3]
t1=3
EXAMPLE

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      tree2 = CFA::AugeasTree.new
      tree2["t1"] = "2"
      tree3 = CFA::AugeasTree.new
      tree3["t1"] = "3"
      tree.add("main2", tree2)
      tree.add("main3", tree3)

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "writes properly new entry of same key as single entry already there" do
      input = <<EXAMPLE
[main]
# test1
EXAMPLE

      expected = <<EXAMPLE
[main]
# test1
#test2
EXAMPLE

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      tree["main"].add("#comment[]", "test2")

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "writes properly new entry with same key as removed entry" do
      input = <<EXAMPLE
[main]
t1 = 1
EXAMPLE

      expected = <<EXAMPLE
[main]
t1 = 2
EXAMPLE

      parser = CFA::AugeasParser.new("puppet.lns")
      tree = parser.parse(input)
      tree["main"].delete("t1")
      tree["main"].add("t1", "2")

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "writes properly multiple subtrees" do
      input = <<EXAMPLE
server 0.pool.ntp.org
server 1.pool.ntp.org
EXAMPLE

      expected = <<EXAMPLE
server 0.pool.ntp.org
server 1.pool.ntp.org
server 2.pool.ntp.org iburst dynamic
server 3.pool.ntp.org iburst
EXAMPLE

      parser = CFA::AugeasParser.new("ntp.lns")
      tree = parser.parse(input)
      servers = tree.collection("server")
      options = CFA::AugeasTree.new
      options["iburst"] = nil
      options["dynamic"] = nil
      servers.add(CFA::AugeasTreeValue.new(options, "2.pool.ntp.org"))
      options = CFA::AugeasTree.new
      options["iburst"] = nil
      servers.add(CFA::AugeasTreeValue.new(options, "3.pool.ntp.org"))

      expect(parser.serialize(tree)).to eq(expected)
    end

    it "writes properly combination of subtree and single entry that is modified (bsc#1132362)" do
      input = <<EXAMPLE
server 1.pool.ntp.org iburst
EXAMPLE

      expected = <<EXAMPLE
server 1.pool.ntp.org iburst
server 3.pool.ntp.org
EXAMPLE

      parser = CFA::AugeasParser.new("ntp.lns")
      tree = parser.parse(input)
      tree["server"].tree.delete("iburst")
      tree["server"].tree.add("iburst", nil)

      tree.add("server[]", CFA::AugeasTreeValue.new(CFA::AugeasTree.new, "3.pool.ntp.org"))

      expect(parser.serialize(tree)).to eq(expected)
    end
  end
end
