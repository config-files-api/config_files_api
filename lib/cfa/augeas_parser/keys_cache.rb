module CFA
  # A cache that holds all avaiable keys in an Augeas tree. It is used to
  # prevent too many `aug.match` calls which are expensive.
  class AugeasKeysCache
    # initialize cache from passed Augeas object
    # @param aug [::Augeas]
    # @param prefix [String] Augeas path for which cache should be created
    def initialize(aug, prefix)
      fill_cache(aug, prefix)
    end

    # @return list of keys available on given prefix
    def keys_for_prefix(prefix)
      @cache[prefix] || []
    end

  private

    def fill_cache(aug, prefix)
      @cache = {}
      search_path = "#{prefix}/*"
      loop do
        matches = aug.match(search_path)
        break if matches.empty?

        assign_matches(matches, @cache)

        search_path += "/*"
      end
    end

    def assign_matches(matches, cache)
      matches.each do |match|
        split_index = match.rindex("/")
        prefix = match[0..(split_index - 1)]
        key = match[(split_index + 1)..-1]
        cache[prefix] ||= []
        cache[prefix] << key
      end
    end
  end
end
