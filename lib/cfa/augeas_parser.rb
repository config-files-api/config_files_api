require "augeas"
require "forwardable"
require "cfa/placer"

module CFA
  # Represents list of same config options in augeas.
  # For example comments are often stored in collections.
  class AugeasCollection
    extend Forwardable
    def initialize(tree, name)
      @tree = tree
      @name = name
      load_collection
    end

    def_delegators :@collection, :[], :empty?, :each, :map, :any?, :all?, :none?

    def add(value, placer = AppendPlacer.new)
      element = placer.new_element(@tree)
      element[:key] = augeas_name
      element[:value] = value
    end

    def delete(value)
      key = augeas_name
      @tree.data.reject! do |entry|
        entry[:key] == key &&
          if value.is_a?(Regexp)
            value =~ entry[:value]
          else
            value == entry[:value]
          end
      end

      load_collection
    end

  private

    def load_collection
      entries = @tree.data.select { |d| d[:key] == augeas_name }
      @collection = entries.map { |e| e[:value] }.freeze
    end

    def augeas_name
      @name + "[]"
    end
  end

  # Represents node that contain value and also subtree below it
  # For easier traversing it pass #[] to subtree
  class AugeasTreeValue
    # value in node
    attr_accessor :value
    # subtree below node
    attr_accessor :tree

    def initialize(tree, value)
      @tree = tree
      @value = value
    end

    def [](value)
      tree[value]
    end
  end

  # Represent parsed augeas config tree with user friendly methods
  class AugeasTree
    # low level access to augeas structure
    attr_reader :data

    def initialize
      @data = []
    end

    def collection(key)
      AugeasCollection.new(self, key)
    end

    def delete(key)
      @data.reject! { |entry| entry[:key] == key }
    end

    # adds the given value for the key in tree.
    # @param value can be value of node, {AugeasTree}
    #   attached to key or its combination as {AugeasTreeValue}
    # @param placer object determining where to insert value in tree.
    #   Useful e.g. to specify order of keys or placing comment above of given
    #   key.
    def add(key, value, placer = AppendPlacer.new)
      element = placer.new_element(self)
      element[:key] = key
      element[:value] = value
    end

    # finds given value in tree.
    # @return It can return value of node, {AugeasTree}
    #   attached to key or its combination as {AugeasTreeValue}.
    #   Also nil can be returned if key not found.
    def [](key)
      entry = @data.find { |d| d[:key] == key }
      return entry[:value] if entry

      nil
    end

    # Sets the given value for the key in tree. It can be value of node,
    # {AugeasTree} attached to key or its combination as {AugeasTreeValue}
    def []=(key, value)
      entry = @data.find { |d| d[:key] == key }
      if entry
        entry[:value] = value
      else
        @data << {
          key:   key,
          value: value
        }
      end
    end

    def select(matcher)
      @data.select(&matcher)
    end

    # @note for internal usage only
    # @private
    def load_from_augeas(aug, prefix, keys_cache)
      @data = keys_cache.keys_for_prefix(prefix).map do |key|
        aug_key = prefix + "/" + key
        {
          key:   load_key(prefix, aug_key),
          value: load_value(aug, aug_key, keys_cache)
        }
      end
    end

    # @note for internal usage only
    # @private
    def save_to_augeas(aug, prefix)
      arrays = {}

      @data.each do |entry|
        save_entry(entry[:key], entry[:value], arrays, aug, prefix)
      end
    end

  private

    def save_entry(key, value, arrays, aug, prefix)
      aug_key = obtain_aug_key(prefix, key, arrays)
      case value
      when AugeasTree then value.save_to_augeas(aug, aug_key)
      when AugeasTreeValue
        report_error(aug) unless aug.set(aug_key, value.value)
        value.tree.save_to_augeas(aug, aug_key)
      else
        report_error(aug) unless aug.set(aug_key, value)
      end
    end

    def obtain_aug_key(prefix, key, arrays)
      if key.end_with?("[]")
        array_key = key[0..-3] # remove trailing []
        arrays[array_key] ||= 0
        arrays[array_key] += 1
        key = array_key + "[#{arrays[array_key]}]"
      end

      "#{prefix}/#{key}"
    end

    def report_error(aug)
      error = aug.error
      raise "Augeas error #{error[:message]}." \
        "Details: #{error[:details]}."
    end

    def load_key(prefix, aug_key)
      # clean from key prefix and for collection remove number inside []
      # +1 for size due to ending '/' not part of prefix
      key = aug_key[(prefix.size + 1)..-1]
      key.end_with?("]") ? key.sub(/\[\d+\]$/, "[]") : key
    end

    def load_value(aug, aug_key, keys_cache)
      subkeys = keys_cache.keys_for_prefix(aug_key)

      nested = !subkeys.empty?
      value = aug.get(aug_key)
      if nested
        subtree = AugeasTree.new
        subtree.load_from_augeas(aug, aug_key, keys_cache)
        value ? AugeasTreeValue.new(subtree, value) : subtree
      else
        value
      end
    end
  end

  # @example read, print, modify and serialize again
  #    require "config_files/augeas_parser"
  #
  #    parser = CFA::AugeasParser.new("sysconfig.lns")
  #    data = parser.parse(File.read("/etc/default/grub"))
  #
  #    puts data["GRUB_DISABLE_OS_PROBER"]
  #    data["GRUB_DISABLE_OS_PROBER"] = "true"
  #    puts parser.serialize(data)
  class AugeasParser
    def initialize(lens)
      @lens = lens
    end

    # parses given string and returns AugeasTree instance
    def parse(raw_string)
      @old_content = raw_string

      # open augeas without any autoloading and it should not touch disk and
      # load lenses as needed only
      root = load_path = nil
      Augeas.open(root, load_path, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", raw_string)
        report_error(aug) unless aug.text_store(@lens, "/input", "/store")

        keys_cache = AugeasKeysCache.new(aug)

        tree = AugeasTree.new
        tree.load_from_augeas(aug, "/store", keys_cache)

        return tree
      end
    end

    # Serializes AugeasTree instance into returned string
    def serialize(data)
      # open augeas without any autoloading and it should not touch disk and
      # load lenses as needed only
      root = load_path = nil
      Augeas.open(root, load_path, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", @old_content || "")
        data.save_to_augeas(aug, "/store")

        res = aug.text_retrieve(@lens, "/input", "/store", "/output")
        report_error(aug) unless res

        return aug.get("/output")
      end
    end

    # Returns empty tree that can be filled for future serialization
    def empty
      AugeasTree.new
    end

  private

    def report_error(aug)
      error = aug.error
      # zero is no error, so problem in lense
      if aug.error[:code].nonzero?
        raise "Augeas error #{error[:message]}. Details: #{error[:details]}."
      end

      msg = aug.get("/augeas/text/store/error/message")
      location = aug.get("/augeas/text/store/error/lens")
      raise "Augeas parsing/serializing error: #{msg} at #{location}"
    end
  end
end

# Cache that holds all avaiable keys in augeas tree. It is used to
# prevent too many aug.match calls which are expensive.
class AugeasKeysCache
  STORE_PREFIX = "/store".freeze
  STORE_LEN = STORE_PREFIX.size
  STORE_LEN_1 = STORE_LEN + 1

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
