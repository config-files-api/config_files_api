require "set"
require "augeas"
require "forwardable"
require "cfa/placer"

# CFA: Configuration Files API
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
  # An `:operation` is an internal variable holding modification of Augeas
  # structure. It is used for minimizing modifications of source files. Its
  # possible values are
  # - `:keep` when the value is untouched
  # - `:modify` when the `:value` changed but the `:key` is the same
  # - `:remove` when it is going to be removed, and
  # - `:add` when a new element is added.
  #
  # An `:orig_key` is an internal variable used to hold the original key
  # including its index.
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
      to_delete, to_mark = to_remove(value)
                           .partition { |e| e[:operation] == :add }
      @tree.all_data.delete_if { |e| to_delete.include?(e) }

      to_mark.each { |e| e[:operation] = :remove }

      load_collection
    end

  private

    def load_collection
      entries = @tree.data.select do |entry|
        entry[:key] == augeas_name && entry[:operation] != :remove
      end
      @collection = entries.map { |e| e[:value] }.freeze
    end

    def augeas_name
      @name + "[]"
    end

    def to_remove(value)
      key = augeas_name

      @tree.data.select do |entry|
        entry[:key] == key && value_match?(entry[:value], value)
      end
    end

    def value_match?(value, match)
      if match.is_a?(Regexp)
        value =~ match
      else
        value == match
      end
    end
  end

  # Represents a node that contains both a value and a subtree below it.
  # For easier traversal it forwards `#[]` to the subtree.
  class AugeasTreeValue
    # @return [String] the value in the node
    attr_reader :value
    # @return [AugeasTree] the subtree below the node
    attr_accessor :tree

    def initialize(tree, value)
      @tree = tree
      @value = value
      @modified = false
    end

    # (see AugeasTree#[])
    def [](key)
      tree[key]
    end

    def value=(value)
      @value = value
      @modified = true
    end

    def ==(other)
      [:class, :value, :tree].all? do |a|
        public_send(a) == other.public_send(a)
      end
    end

    # @return true if the value has been modified
    def modified?
      @modified
    end

    # For objects of class Object, eql? is synonymous with ==:
    # http://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==
  end

  # Represents a parsed Augeas config tree with user friendly methods
  class AugeasTree
    # Low level access to Augeas structure
    #
    # An ordered mapping, represented by an Array of AugeasElement, but without
    # any removed elements.
    #
    # @see AugeasElement
    #
    # @return [Array<Hash{Symbol => Object}>] a frozen array as it is
    #    just a copy of the real data
    def data
      @data.reject { |e| e[:operation] == :remove }.freeze
    end

    # low level access to all AugeasElement including ones marked for removal
    def all_data
      @data
    end

    def initialize
      @data = []
    end

    # Gets new unique id in numberic sequence. Useful for augeas models that
    # using sequences like /etc/hosts . It have keys like "1", "2" and when
    # adding new one it need to find new key.
    def unique_id
      # check all_data instead of data, as we have to not reuse deleted key
      ids = Set.new(all_data.map { |e| e[:key] })
      id = 1
      loop do
        return id.to_s unless ids.include?(id.to_s)
        id += 1
      end
    end

    # @return [AugeasCollection] collection for *key*
    def collection(key)
      AugeasCollection.new(self, key)
    end

    # @param [String, Matcher] matcher
    def delete(matcher)
      return if matcher.nil?
      unless matcher.is_a?(CFA::Matcher)
        matcher = CFA::Matcher.new(key: matcher)
      end
      to_remove = @data.select(&matcher)

      to_delete, to_mark = to_remove.partition { |e| e[:operation] == :add }
      @data -= to_delete
      to_mark.each { |e| e[:operation] = :remove }
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
    # If *key* was previously removed, then put it back to its old position.
    # @param key [String]
    # @param value [String, AugeasTree, AugeasTreeValue]
    def []=(key, value)
      new_entry = entry_to_modify(key, value)
      new_entry[:key] = key
      new_entry[:value] = value
    end

    # @param matcher [Matcher]
    # @return [Array<AugeasElement>] matching elements
    def select(matcher)
      data.select(&matcher)
    end

    def ==(other)
      return false if self.class != other.class
      other_data = other.data # do not compute again
      data.each_with_index do |entry, index|
        other_entry = other_data[index]
        return false unless other_entry
        return false if entry[:key] != other_entry[:key]
        return false if entry[:value] != other_entry[:value]
      end

      true
    end

    # For objects of class Object, eql? is synonymous with ==:
    # http://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==

  private

    def replace_entry(old_entry)
      index = @data.index(old_entry)
      new_entry = { operation: :add }
      # insert the replacement to the same location
      @data.insert(index, new_entry)
      # the entry is not yet in the tree
      if old_entry[:operation] == :add
        @data.delete_if { |d| d[:key] == key }
      else
        old_entry[:operation] = :remove
      end

      new_entry
    end

    def mark_new_entry(new_entry, old_entry)
      # if an entry already exists then just modify it,
      # but only if we previously did not add it
      new_entry[:operation] = if old_entry && old_entry[:operation] != :add
                                :modify
                              else
                                :add
                              end
    end

    def entry_to_modify(key, value)
      entry = @data.find { |d| d[:key] == key }
      # we are switching from tree to value or treevalue to value only
      # like change from key=value to key=value#comment
      if entry && entry[:value].class != value.class
        entry = replace_entry(entry)
      end
      new_entry = entry || {}
      mark_new_entry(new_entry, entry)

      @data << new_entry unless entry

      new_entry
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
    # @param file_name [String] a file name, for error reporting ONLY
    # @return [AugeasTree] the parsed data
    def parse(raw_string, file_name = nil)
      require "cfa/augeas_parser/reader"
      # Workaround for augeas lenses that don't handle files
      # without a trailing newline (bsc#1064623, bsc#1074891, bsc#1080051
      # and gh#hercules-team/augeas#547)
      raw_string += "\n" unless raw_string.end_with?("\n")
      @old_content = raw_string

      # open augeas without any autoloading and it should not touch disk and
      # load lenses as needed only
      root = load_path = nil
      Augeas.open(root, load_path, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", raw_string)
        report_error(aug, "parsing", file_name) \
          unless aug.text_store(@lens, "/input", "/store")

        return AugeasReader.read(aug, "/store")
      end
    end

    # @param data [AugeasTree] the data to be serialized
    # @param file_name [String] a file name, for error reporting ONLY
    # @return [String] a string to be written
    def serialize(data, file_name = nil)
      require "cfa/augeas_parser/writer"
      # open augeas without any autoloading and it should not touch disk and
      # load lenses as needed only
      root = load_path = nil
      Augeas.open(root, load_path, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", @old_content || "")
        aug.text_store(@lens, "/input", "/store") if @old_content
        AugeasWriter.new(aug).write("/store", data)

        res = aug.text_retrieve(@lens, "/input", "/store", "/output")
        report_error(aug, "serializing", file_name) unless res

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
    # @param activity ["parsing", "serializing"] for better error messages
    # @param file_name [String,nil] a file name
    def report_error(aug, activity, file_name)
      error = aug.error
      # zero is no error, so problem in lense
      if error[:code].nonzero?
        raise "Augeas error: #{error[:message]}. Details: #{error[:details]}."
      end

      file_name ||= "(unknown file)"
      raise format("Augeas #{activity} error: %<message>s" \
                   " at #{file_name}:%<line>s:%<char>s, lens %<lens>s",
        aug_get_error(aug))
    end

    def aug_get_error(aug)
      {
        message: aug.get("/augeas/text/store/error/message"),
        line:    aug.get("/augeas/text/store/error/line"),
        char:    aug.get("/augeas/text/store/error/char"), # column
        # file, line+column range, like
        # "/usr/share/augeas/lenses/dist/hosts.aug:23.12-.42:"
        lens:    aug.get("/augeas/text/store/error/lens")
      }
    end
  end
end
