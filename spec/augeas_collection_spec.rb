# frozen_string_literal: true

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
