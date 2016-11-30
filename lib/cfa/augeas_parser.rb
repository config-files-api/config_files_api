require "augeas"
require "forwardable"
require "cfa/placer"

module CFA
  # A building block for {AugeasTree}.
  #
  # Intuitively the tree is made of hashes where keys may be duplicated,
  # so it is implemented as a sequence of hashes with two keys, :key and :value.
  #
  # A `:key` is a String.
  # The key may have a collection suffix "[]". Note that in contrast
  # with the underlying {::Augeas} library, an integer index is not present
  # (which should make it easier to modify collections of elements).
  #
  # A `:value` is either a String, or an {AugeasTree},
  # or an {AugeasTreeValue} (which combines both).
  #
  # @return [Hash{Symbol => String, AugeasTree}]
  #
  # @todo Unify naming: entry, element
  class AugeasElement < Hash
  end

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
      # FIXME: load_collection missing here
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

  # Represents a node that contains both a value and a subtree below it.
  # For easier traversal it forwards `#[]` to the subtree.
  class AugeasTreeValue
    # @return [String] the value in the node
    attr_accessor :value
    # @return [AugeasTree] the subtree below the node
    attr_accessor :tree

    def initialize(tree, value)
      @tree = tree
      @value = value
    end

    # (see AugeasTree#[])
    def [](key)
      tree[key]
    end

    def ==(other)
      other.class == self.class &&
        other.value == value &&
        other.tree == tree
    end

    # For objects of class Object, eql? is synonymous with ==:
    # http://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==
  end

  # Represents a parsed Augeas config tree with user friendly methods
  class AugeasTree
    # Low level access to Augeas structure
    #
    # An ordered mapping, represented by an Array of Hashes
    # with the keys :key and :value.
    #
    # @see AugeasElement
    #
    # @return [Array<Hash{Symbol => String, AugeasTree}>]
    attr_reader :data

    def initialize
      @data = []
    end

    # @return [AugeasCollection] collection for *key*
    def collection(key)
      AugeasCollection.new(self, key)
    end

    # @param [String, Matcher]
    def delete(matcher)
      if matcher.is_a?(CFA::Matcher)
        @data.reject!(&matcher)
      else
        @data.reject! { |entry| entry[:key] == matcher }
      end
    end

    # Adds the given *value* for *key* in the tree.
    #
    # By default an AppendPlacer is used which produces duplicate keys
    # but ReplacePlacer can be used to replace the *first* duplicate.
    # @param key [String]
    # @param value [String,AugeasTree,AugeasTreeValue]
    # @param placer [Placer] determines where to insert value in tree.
    #   Useful e.g. to specify order of keys or placing comment above of given
    #   key.
    def add(key, value, placer = AppendPlacer.new)
      element = placer.new_element(self)
      element[:key] = key
      element[:value] = value
    end

    # Finds given *key* in tree.
    # @param key [String]
    # @return [String,AugeasTree,AugeasTreeValue,nil] the first value for *key*,
    #   or `nil` if not found
    def [](key)
      entry = @data.find { |d| d[:key] == key }
      return entry[:value] if entry

      nil
    end

    # Replace the first value for *key* with *value*.
    # Append a new element if *key* did not exist.
    # @param key [String]
    # @param value [String, AugeasTree, AugeasTreeValue]
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

    # @param matcher [Matcher]
    # @return [Array<AugeasElement>] matching elements
    def select(matcher)
      @data.select(&matcher)
    end

    # @note for internal usage only
    # @api private
    #
    # Initializes {#data} from *prefix* in *aug*.
    # @param aug [::Augeas]
    # @param prefix [String] Augeas path prefix
    # @param keys_cache [AugeasKeysCache]
    # @return [void]
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
    # @api private
    #
    # Saves {#data} to *prefix* in *aug*.
    # @param aug [::Augeas]
    # @param prefix [String] Augeas path prefix
    # @return [void]
    def save_to_augeas(aug, prefix)
      arrays = {}

      @data.each do |entry|
        save_entry(entry[:key], entry[:value], arrays, aug, prefix)
      end
    end

    def ==(other)
      other.class == self.class &&
        other.data == data
    end

    # For objects of class Object, eql? is synonymous with ==:
    # http://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==

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
  #    require "cfa/augeas_parser"
  #
  #    parser = CFA::AugeasParser.new("Sysconfig.lns")
  #    data = parser.parse(File.read("/etc/default/grub"))
  #
  #    puts data["GRUB_DISABLE_OS_PROBER"]
  #    data["GRUB_DISABLE_OS_PROBER"] = "true"
  #    puts parser.serialize(data)
  class AugeasParser
    # @param lens [String] a lens name, like "Sysconfig.lns"
    def initialize(lens)
      @lens = lens
    end

    # @param raw_string [String] a string to be parsed
    # @return [AugeasTree] the parsed data
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

    # @param data [AugeasTree] the data to be serialized
    # @return [String] a string to be written
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

    # @return [AugeasTree] an empty tree that can be filled
    #   for future serialization
    def empty
      AugeasTree.new
    end

  private

    # @param aug [::Augeas]
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
end
