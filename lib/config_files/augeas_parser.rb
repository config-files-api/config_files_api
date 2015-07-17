require "augeas"
require "forwardable"

module ConfigFiles
  class AugeasMatcher
    def initialize(key: nil, collection: nil, value_matcher: nil)
      @matcher = lambda do |element|
        return false if key && element[:key] != key
        return false if collection && element[:key] != collection + "[]"
        return false if value_matcher && !(value_matcher === element[:value])
        return true
      end
    end

    def to_proc
      @matcher
    end
  end

  # allows to place element to certain place
  class AugeasAppendPlacer
    def new_element(tree)
      res = {}
      tree.data << res

      res
    end
  end

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

    def delete(matcher)
      key = augeas_name
      @tree.data.reject! do |entry|
        entry[:key] == key && matcher === entry[:value]
      end

      load_collection
    end

  private
     def load_collection
      entries = @tree.data.select{|d| d[:key] == augeas_name}
      @collection = entries.map{|e| e[:value]}.freeze
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
      entry = @data.find{|d| d[:key] == key}
      return entry[:value] if entry

      return nil
    end

    def []=(key, value)
      entry = @data.find{|d| d[:key] == key}
      if entry
        entry[:value] = value
      else
        @data << {
          key:   key,
          value: value
        }
      end
    end

    # @note for internal usage only
    # @private
    def load_from_augeas(aug, prefix)
      matches = aug.match("#{prefix}/*")

      @data = matches.map do |aug_key|
        key = aug_key.sub(/^#{Regexp.escape(prefix)}\//, "")
        key.sub!(/\[\d+\]$/, "[]")
        res = { key: key}
        nested = !aug.match("#{aug_key}/*").empty?
        if nested
          subtree = AugeasTree.new
          subtree.load_from_augeas(aug, aug_key)
          res[:value] = subtree
        else
          res[:value] = aug.get(aug_key)
        end

        res
      end
    end

    # @note for internal usage only
    # @private
    def save_to_augeas(aug, prefix)
      arrays = {}

      @data.each do |entry|
        key = entry[:key]
        if key.end_with?("[]")
          array_key = key.sub(/\[\]$/, "")
          arrays[array_key] ||= 0
          arrays[array_key] += 1
          key = array_key + "[#{arrays[array_key]}]"
        end
        aug_key = "#{prefix}/#{key}"
        if entry[:value].is_a? AugeasTree
          entry[:value].save_to_augeas(aug, aug_key)
        else
          if !aug.set(aug_key, entry[:value])
            error = aug.error
            raise "Augeas error #{error[:message]}. Details: #{error[:details]}."
          end
        end
      end
    end

    # @note for debugging purpose only
    def dump_tree(prefix="")
      arrays = {}
      res = ""

      @data.each do |entry|
        key = entry[:key]
        if key.end_with?("[]")
          array_key = key.sub(/\[\]$/, "")
          arrays[array_key] ||= 0
          arrays[array_key] += 1
          key = array_key + "[#{arrays[array_key]}]"
        end
        aug_key = "#{prefix}/#{key}"
        if entry[:value].is_a? AugeasTree
          res += entry[:value].dump_tree(aug_key)
        else
          res += aug_key + "\n"
        end
      end

      res
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
      Augeas::open(root, load_path, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", raw_string)
        if !aug.text_store(@lens, "/input", "/store")
           error = aug.error
          # zero is no error, so problem in lense
          if aug.error[:code] != 0
            raise "Augeas error #{error[:message]}. Details: #{error[:details]}."
          else
            msg = aug.get("/augeas/text/store/error/message")
            location = aug.get("/augeas/text/store/error/lens")
            raise "Augeas parsing error: #{msg} at #{location}"
          end
        end

        tree = AugeasTree.new
        tree.load_from_augeas(aug, "/store")

        return tree
      end
    end

    def serialize(data)

      # open augeas without any autoloading and it should not touch disk and
      # load lenses as needed only
      root = load_path = nil
      Augeas::open(root, load_path, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", @old_content || "")
        data.save_to_augeas(aug, "/store")

        if !aug.text_retrieve(@lens, "/input", "/store", "/output")
          error = aug.error
          # zero is no error, so problem in lense
          if aug.error[:code] != 0
            raise "Augeas error #{error[:message]}. Details: #{error[:details]}."
          else
            msg = aug.get("/augeas/text/store/error/message")
            location = aug.get("/augeas/text/store/error/lens")
            raise "Augeas serializing error: #{msg} at #{location}"
          end
        end

        return aug.get("/output")
      end
    end
  end
end
