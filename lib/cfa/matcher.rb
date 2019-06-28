# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module CFA
  # The Matcher is used as a predicate on {AugeasElement}.
  #
  # Being a predicate, it is passed  to methods such as Enumerable#select
  # or Array#index, returning a Boolean meaning whether a match was found.
  #
  # Acting on {AugeasElement} means it expects a Hash `e`
  # containing `e[:key]` and `e[:value]`.
  #
  # It is used with the `&` syntax which makes the matcher
  # act like a block/lambda/Proc (via {Matcher#to_proc}).
  #
  # @note The coupling to {AugeasTree}, {AugeasElement} is not a goal.
  #   Once we have more parsers it will go away.
  #
  # @example
  #    elements = [
  #                {key: "#comment[]", value: "\"magical\" mostly works"},
  #                {key: "DRIVE",      value: "magical"},
  #                {key: "#comment[]", value: "'years' or 'centuries'"},
  #                {key: "PRECISION",  value: "years"}
  #               ]
  #    drive_matcher = Matcher.new(key: "DRIVE")
  #    i = elements.index(&drive_matcher)        # => 1
  class Matcher
    # The constructor arguments are constraints to match on an element.
    # All constraints are optional.
    # All supplied constraints must match, so it is a conjunction.
    # @param key           [Object,nil] if non-nil,
    #   constrain to elements with the name "*key*"
    # @param collection    [Object,nil] if non-nil,
    #   constrain to elements with the name "*collection*[]"
    # @param value_matcher [Object,Regexp,nil] if non-nil,
    #   constrain to elements whose value is Object or matches Regexp
    # @yieldparam blk_key   [Object]
    # @yieldparam blk_value [Object]
    # @yieldreturn      [Boolean] if the block is present,
    #   constrain to elements for which the block(*blk_key*, *blk_value*)
    #   returns true
    def initialize(key: nil, collection: nil, value_matcher: nil, &block)
      @matcher = lambda do |element|
        return false unless key_match?(element, key)
        return false unless collection_match?(element, collection)
        return false unless value_match?(element, value_matcher)
        return false unless !block || yield(element[:key], element[:value])

        return true
      end
      @matcher = T.let(@matcher, T.proc.params(e: T.untyped).returns(T::Boolean))
    end

    # @return [Proc{AugeasElement=>Boolean}]
    def to_proc
      @matcher
    end

  private

    def key_match?(element, key)
      return true unless key

      element[:key] == key
    end

    def collection_match?(element, collection)
      return true unless collection

      element[:key] == (collection + "[]")
    end

    def value_match?(element, matcher)
      case matcher
      when nil then true
      when Regexp
        return false unless element[:value].is_a?(String)

        matcher =~ element[:value]
      else
        matcher == element[:value]
      end
    end
  end
end
