module ConfigFiles
  # Class used to create matcher, that allows to find specific option in augeas
  # tree or subtree
  # TODO: examples of usage
  class Matcher
    def initialize(key: nil, collection: nil, value_matcher: nil)
      @matcher = lambda do |element|
        return false unless key_match?(element, key)
        return false unless collection_match?(element, collection)
        return false unless value_match?(element, value_matcher)
        return true
      end
    end

    def to_proc
      @matcher
    end

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
