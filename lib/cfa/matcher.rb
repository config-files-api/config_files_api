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
    # @param key           [Object,nil] foo
    # @param collection    [Object,nil] bar
    # @param value_matcher [Object,nil] baz
    # @param block         [MatcherBinaryPredicate,nil]
    def initialize(key: nil, collection: nil, value_matcher: nil, &block)
      @matcher = lambda do |element|
        return false unless key_match?(element, key)
        return false unless collection_match?(element, collection)
        return false unless value_match?(element, value_matcher)
        return false unless !block || block.call(element[:key], element[:value])
        return true
      end
    end

    # @return [Proc] see {#call} for its API
    def to_proc
      @matcher
    end

    # @param element [Hash] containing
    #   * `:key`
    #   * `:value`
    # @return [Boolean] whether the *element* matched
    def call(element)
      to_proc.call(element)
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

  # An abstract class documenting the block argument to {Matcher#initialize}
  class MatcherBinaryPredicate < Proc
    # @param key [Object]
    # @param value [Object]
    # @return [Boolean]
    def call(key, value)
      abstract_method(key, value)
    end
  end
end
