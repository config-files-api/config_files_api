require "augeas"
require "forwardable"

module ConfigFiles
  # @note highly coupled with AugeasTree class
  class AugeasCollection
    extend Forwardable
    def initialize(tree, name)
      @tree = tree
      @name = name
      load_collection
    end

    def_delegators :@collection, :[], :empty?, :each, :map, :any?, :all?, :none?

    def add(value, where = { :append => true})
      # TODO
    end

    def delete(matcher)
      key = @name + "[]"
      @tree.data.reject! do |entry|
        entry[:key] == key && matcher === entry[:value]
      end

      load_collection
    end

  private
     def load_collection
      entries = @tree.data.select{|d| d[:key] == @name + "[]"}
      @collection = entries.map{|e| e[:value]}.freeze
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

    # possible where:
    #   append: true # append to the end of parser file
    #   before_key: "key" # add before entry with given key
    #   after_key:  "key" # add after entry with given key
    #   before_collection_entry: { name: "my_collection", matcher: /entry 5/ }
    #   after_collection_entry: { name: "my_collection", matcher: /entry 5/ }
    #     adds before/after entry matching (===) matcher in given collection
    def add(key, value, where = { append: true })
      raise "not yet implemented"
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
