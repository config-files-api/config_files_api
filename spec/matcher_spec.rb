# typed: false
# frozen_string_literal: true

require_relative "spec_helper"
require "cfa/matcher"

describe CFA::Matcher do
  let(:test_data) do
    [
      { key: "A", value: "valA" },
      { key: "keyA", value: "A" },
      { key: "A[]", value: "first" },
      { key: "A[]", value: "second" }
    ]
  end

  describe ".new" do
    it "can be constructed with key specified" do
      matcher = described_class.new(key: "A")
      matched = test_data.select(&matcher)
      expect(matched.size).to eq 1
      expect(matched.first[:value]).to eq "valA"
    end

    it "can be constructed with collection name specified" do
      matcher = described_class.new(collection: "A")
      matched = test_data.select(&matcher)
      expect(matched.size).to eq 2
      expect(matched.map { |v| v[:value] }).to eq ["first", "second"]
    end

    it "can be constructed with value_matcher specified as string" do
      matcher = described_class.new(value_matcher: "A")
      matched = test_data.select(&matcher)
      expect(matched.size).to eq 1
      expect(matched.first[:key]).to eq "keyA"
    end

    it "can be constructed with value_matcher specified as regexp" do
      matcher = described_class.new(value_matcher: /A/)
      matched = test_data.select(&matcher)
      expect(matched.size).to eq 2
      expect(matched.first[:key]).to eq "A"
    end

    it "can be constructed with block specified" do
      matcher = described_class.new { |key, value| key == "A" || value == "A" }
      matched = test_data.select(&matcher)
      expect(matched.size).to eq 2
      expect(matched.first[:key]).to eq "A"
    end

    it "have to pass all specification passed" do
      matcher = described_class.new(collection: "A", value_matcher: "first")
      matched = test_data.select(&matcher)
      expect(matched.size).to eq 1
      expect(matched.map { |v| v[:value] }).to eq ["first"]
    end
  end
end
