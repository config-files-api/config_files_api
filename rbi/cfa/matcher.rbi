# typed: strong
# frozen_string_literal: true

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
    sig {params(key: T.untyped, collection: T.untyped, value_matcher: T.untyped).void}
    def initialize(key: nil, collection: nil, value_matcher: nil, &block)
    end

    # @return [Proc{AugeasElement=>Boolean}]
    sig { returns(T.proc.params(e: T.untyped).returns(T::Boolean)) }
    def to_proc
    end

  private

    sig { params(element: T.untyped, key: T.untyped).returns(T::Boolean) }
    def key_match?(element, key)
    end

    sig { params(element: T.untyped, collection: T.untyped).returns(T::Boolean) }
    def collection_match?(element, collection)
    end

    sig { params(element: T.untyped, matcher: T.untyped).returns(T::Boolean) }
    def value_match?(element, matcher)
    end
  end
end
