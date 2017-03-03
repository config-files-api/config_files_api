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
      element[:operation] = :add
      # FIXME: load_collection missing here
    end

    def delete(value)
      key = augeas_name
      to_remove = @tree.data.select do |entry|
        entry[:key] == key &&
          if value.is_a?(Regexp)
            value =~ entry[:value]
          else
            value == entry[:value]
          end
      end

      to_remove.each { |e| e[:operation] = :remove }

      load_collection
    end

  private

    def load_collection
      entries = @tree.data.select { |d| d[:key] == augeas_name && d[:operation] != :remove }
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
      [:class, :value, :tree].all? do |a|
        public_send(a) == other.public_send(a)
      end
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
    # with the keys :key, :value, :operation and :orig_key.
    #
    # - `:key` is modified key without index used by collection
    # - `:value` is string value or instance of AugeasTree or AugeasTreeValue
    # - `:operation` is internal variable holding modification of augeas structure.
    #   it is used for minimal modification of source file
    # - `:orig_key` is internal variable used to hold key with index
    #
    # @param filtered [true, false] if true, elements with remove operation are filtered from output
    #
    # @see AugeasElement
    #
    # @return [Array<Hash{Symbol => Object}>] if filtered array is returned it 
    #   is frozen, as modifications do not make sense there
    def data(filtered: true)
      if filtered
        @data.select{ |e| e[:operation] != :remove }.freeze
      else
        @data
      end
    end

    def initialize
      @data = []
    end

    # @return [AugeasCollection] collection for *key*
    def collection(key)
      AugeasCollection.new(self, key)
    end

    # @param [String, Matcher]
    def delete(matcher)
      return if matcher.nil?
      unless matcher.is_a?(CFA::Matcher)
        matcher = CFA::Matcher.new(key: matcher)
      end
      to_remove = @data.select(&matcher)
      to_remove.each { |e| e[:operation] = :remove }
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
      element[:operation] = :add
    end

    # Finds given *key* in tree.
    # @param key [String]
    # @return [String,AugeasTree,AugeasTreeValue,nil] the first value for *key*,
    #   or `nil` if not found
    def [](key)
      entry = @data.find { |d| d[:key] == key && d[:operation] != :remove }
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
        entry[:operation] = :modify
      else
        @data << {
          key:   key,
          value: value,
          operation: :add
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
          value: load_value(aug, aug_key, keys_cache),
          orig_key: stripped_path(prefix, aug_key),
          operation: :keep
        }
      end
    end

    def ==(other)
      self.class == other.class &&
        data == other.data
    end

    # For objects of class Object, eql? is synonymous with ==:
    # http://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==

  private

    def load_key(prefix, aug_key)
      # clean from key prefix and for collection remove number inside []
      # +1 for size due to ending '/' not part of prefix
      key = stripped_path(prefix, aug_key)
      key.end_with?("]") ? key.sub(/\[\d+\]$/, "[]") : key
    end

    def stripped_path(prefix, aug_key)
      aug_key[(prefix.size + 1)..-1]
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

  # Smart writer trying to do as less modification as possible.
  # @note internal only, unstable API
  class AugeasWriter
    def self.write(aug, prefix, tree)
      last_valid_entry_path = nil
      tree.data(filtered: false).each do |entry|
        if entry[:key].end_with?("[]")
          if entry[:orig_key]
            key = entry[:orig_key]
            path = prefix + "/" + key
          else
            all_elements = tree.data(filtered: false).select { |e| e[:key] == entry[:key] }
            nums = all_elements.map { |e| e[:orig_key] ? e[:orig_key][/^.*\[(\d+)\]$/, 1].to_i : 0 }
            new_number = nums.max ? (nums.max + 1) : 1
            key = entry[:key][0..-2] + new_number.to_s + "]"
            path = prefix + "/" + key
          end
        else
          key = entry[:key]
          path = prefix + "/" + key
        end
        operation = entry[:operation] || :add
        case operation
        when :add
          if last_valid_entry_path
            report_error(aug) unless aug.insert(last_valid_entry_path, key, false)
          else
            e = find_first_valid(tree.data(filtered: false))
            if e
              e_path = prefix + "/" + e[:orig_key]
              report_error(aug) unless aug.insert(e_path, path, true)
            end
          end
          set_entry(aug, path, entry[:value])
          last_valid_entry_path = path
        when :remove
          report_error(aug) unless aug.rm(path)
        when :modify
          set_entry(aug, path, entry[:value])
          last_valid_entry_path = path
        when :keep
          if entry[:value].is_a?(AugeasTree)
              write(aug, path, entry[:value])
          elsif entry[:value].is_a?(AugeasTreeValue)
              write(aug, path, entry[:value].tree)
          end
          last_valid_entry_path = path
        else
          raise "invalid operation"
        end
      end
    end

    private_class_method def self.set_entry(aug, path, value)
      case value
      when AugeasTree
        report_error(aug) unless aug.touch(path)
        write(aug, path, value)
      when AugeasTreeValue
        report_error(aug) unless aug.set(path, value.value)
        write(aug, path, value.tree)
      else
        report_error(aug) unless aug.set(path, value)
      end
    end

    private_class_method def self.find_first_valid(data)
      data.find { |e| [:keep, :modify].include?(e[:operation]) }
    end

    # @param aug [::Augeas]
    private_class_method def self.report_error(aug)
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
        aug.text_store(@lens, "/input", "/store") if @old_content
        AugeasWriter.write(aug, "/store", data)

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
