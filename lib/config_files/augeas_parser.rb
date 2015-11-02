require "augeas"
require "forwardable"

module ConfigFiles
  # Class used to create matcher, that allows to find specific option in augeas
  # tree or subtree
  # TODO: examples of usage
  class AugeasMatcher
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

  # allows to place element at the end of configuration. Default one.
  class AugeasAppendPlacer
    def new_element(tree)
      res = {}
      tree.data << res

      res
    end
  end

  # Specialized placer, that allows to place config value before found one.
  # Useful, when config option should be inserted to specific location.
  class AugeasBeforePlacer
    def initialize(matcher)
      @matcher = matcher
    end

    def new_element(tree)
      index = tree.data.index(&@matcher)
      raise "Augeas element not found" unless index

      res = {}
      tree.data.insert(index, res)
      res
    end
  end

  # Specialized placer, that allows to place config value after found one.
  # Useful, when config option should be inserted to specific location.
  class AugeasAfterPlacer
    def initialize(matcher)
      @matcher = matcher
    end

    def new_element(tree)
      index = tree.data.index(&@matcher)
      raise "Augeas element not found" unless index

      res = {}
      tree.data.insert(index + 1, res)
      res
    end
  end

  # Specialized placer, that allows to place config value instead of found one.
  # Useful, when value already exists and detected by matcher. Then easy add
  # with this placer replace it carefully to correct location.
  class AugeasReplacePlacer
    def initialize(matcher)
      @matcher = matcher
    end

    def new_element(tree)
      index = tree.data.index(&@matcher)
      raise "Augeas element not found" unless index

      res = {}
      tree.data[index] = res
      res
    end
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

    def add(value, placer = AugeasAppendPlacer.new)
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

    def add(key, value, placer = AugeasAppendPlacer.new)
      element = placer.new_element(self)
      element[:key] = key
      element[:value] = value
    end

    def [](key)
      entry = @data.find { |d| d[:key] == key }
      return entry[:value] if entry

      nil
    end

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

    def select(&matcher)
      @data.select(&matcher)
    end

    # @note for internal usage only
    # @private
    def load_from_augeas(aug, prefix)
      matches = aug.match("#{prefix}/*")

      @data = matches.map do |aug_key|
        {
          key:   load_key(prefix, aug_key),
          value: load_value(aug, aug_key)
        }
      end
    end

    # @note for internal usage only
    # @private
    def save_to_augeas(aug, prefix)
      arrays = {}

      @data.each do |entry|
        aug_key = obtain_aug_key(prefix, entry, arrays)
        if entry[:value].is_a? AugeasTree
          entry[:value].save_to_augeas(aug, aug_key)
        else
          report_error(aug) unless aug.set(aug_key, entry[:value])
        end
      end
    end

    # @note for debugging purpose only
    def dump_tree(prefix = "")
      arrays = {}

      @data.each_with_object("") do |entry, res|
        aug_key = obtain_aug_key(prefix, entry, arrays)
        if entry[:value].is_a? AugeasTree
          res << entry[:value].dump_tree(aug_key)
        else
          res << aug_key << "\n"
        end
      end
    end

  private

    def obtain_aug_key(prefix, entry, arrays)
      key = entry[:key]
      if key.end_with?("[]")
        array_key = key.sub(/\[\]$/, "")
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
      key = aug_key.sub(/^#{Regexp.escape(prefix)}\//, "")
      key.sub(/\[\d+\]$/, "[]")
    end

    def load_value(aug, aug_key)
      nested = !aug.match("#{aug_key}/*").empty?
      if nested
        subtree = AugeasTree.new
        subtree.load_from_augeas(aug, aug_key)
        subtree
      else
        aug.get(aug_key)
      end
    end
  end

  # @example read, print, modify and serialize again
  #    require "config_files/augeas_parser"
  #
  #    parser = ConfigFiles::AugeasParser.new("sysconfig.lns")
  #    data = parser.parse(File.read("/etc/default/grub"))
  #
  #    puts data["GRUB_DISABLE_OS_PROBER"]
  #    data["GRUB_DISABLE_OS_PROBER"] = "true"
  #    puts parser.serialize(data)
  class AugeasParser
    def initialize(lens)
      @lens = lens
    end

    def parse(raw_string)
      @old_content = raw_string

      # open augeas without any autoloading and it should not touch disk and
      # load lenses as needed only
      root = load_path = nil
      Augeas.open(root, load_path, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", raw_string)
        report_error(aug) unless aug.text_store(@lens, "/input", "/store")

        tree = AugeasTree.new
        tree.load_from_augeas(aug, "/store")

        return tree
      end
    end

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

  private

    def report_error(aug)
      error = aug.error
      # zero is no error, so problem in lense
      if aug.error[:code] != 0
        raise "Augeas error #{error[:message]}. Details: #{error[:details]}."
      else
        msg = aug.get("/augeas/text/store/error/message")
        location = aug.get("/augeas/text/store/error/lens")
        raise "Augeas parsing/serializing error: #{msg} at #{location}"
      end
    end
  end
end
