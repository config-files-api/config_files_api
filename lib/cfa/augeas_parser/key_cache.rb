module CFA
  # Cache that holds all avaiable keys in augeas tree. It is used to
  # prevent too many aug.match calls which are expensive.
  class AugeasKeysCache
    STORE_PREFIX = "/store".freeze

    # initialize cache from passed augeas object
    def initialize(aug)
      fill_cache(aug)
    end

    # returns list of keys available on given prefix
    def keys_for_prefix(prefix)
      @cache[prefix] || []
    end

  private

    def fill_cache(aug)
      @cache = {}
      search_path = "#{STORE_PREFIX}/*"
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
