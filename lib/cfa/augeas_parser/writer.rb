module CFA
  # The goal of this class is to write the data stored in {AugeasTree}
  # back to Augeas.
  #
  # It tries to make only the needed changes, as internally Augeas keeps
  # a flag whether data has been modified,
  # and keeps the unmodified parts of the file untouched.
  #
  # @note internal only, unstable API
  # @api private
  class AugeasWriter
    # @param aug result of Augeas.create
    def initialize(aug)
      @aug = aug
    end

    # Writes the data in *tree* to a given *prefix* in Augeas
    # @param prefix [String] where to write *tree* in Augeas
    # @param tree [CFA::AugeasTree] tree to write
    def write(prefix, tree, top_level: true)
      @lazy_operations = LazyOperations.new(aug) if top_level
      tree.all_data.each do |entry|
        located_entry = LocatedEntry.new(tree, entry, prefix)
        process_operation(located_entry)
      end
      @lazy_operations.run if top_level
    end

  private

    # {AugeasElement} together with information about its location and a few
    # helper methods to detect siblings.
    #
    # @example data for an already existing comment living under /main
    #   entry.orig_key # => "#comment[15]"
    #   entry.path # => "/main/#comment[15]"
    #   entry.key # => "#comment"
    #   entry.entry_tree # => AugeasTree.new
    #   entry.entry_value # => "old boring comment"
    #
    # @example data for a new comment under /main
    #   entry.orig_key # => nil
    #   entry.path # => nil
    #   entry.key # => "#comment"
    #   entry.entry_tree # => AugeasTree.new
    #   entry.entry_value # => "new boring comment"
    #
    # @example data for new tree placed at /main
    #   entry.orig_key # => "main"
    #   entry.path # => "/main"
    #   entry.key # => "main"
    #   entry.entry_tree # => entry[:value]
    #   entry.entry_value # => nil
    #
    class LocatedEntry
      attr_reader :prefix
      attr_reader :entry
      attr_reader :tree

      def initialize(tree, entry, prefix)
        @tree = tree
        @entry = entry
        @prefix = prefix
        detect_tree_value_modification
      end

      def orig_key
        entry[:orig_key]
      end

      def path
        return @path if @path
        return nil unless orig_key

        @path = @prefix + "/" + orig_key
      end

      def key
        return @key if @key

        @key = @entry[:key]
        @key = @key[0..-3] if @key.end_with?("[]")
        @key
      end

      # @return [LocatedEntry, nil]
      #   a preceding entry that already exists in the Augeas tree
      #   or nil if it does not exist.
      def preceding_existing
        preceding_entry = preceding_entries.reverse_each.find do |entry|
          entry[:operation] != :add
        end

        return nil unless preceding_entry

        LocatedEntry.new(tree, preceding_entry, prefix)
      end

      # @return [true, false] returns true if there is any following entry
      #    in the Augeas tree
      def any_following?
        following_entries.any? { |e| e[:operation] != :remove }
      end

      # @return [AugeasTree] the Augeas tree nested under this entry.
      #   If there is no such tree, it creates an empty one.
      def entry_tree
        value = entry[:value]
        case value
        when AugeasTree then value
        when AugeasTreeValue then value.tree
        else AugeasTree.new
        end
      end

      # @return [String, nil] the Augeas value of this entry. Can be nil.
      # If the value is an {AugeasTree} then return nil.
      def entry_value
        value = entry[:value]
        case value
        when AugeasTree then nil
        when AugeasTreeValue then value.value
        else value
        end
      end

    private

      # For {AugeasTreeValue} we have a problem with detection of
      # value modification as it is enclosed in a diferent object.
      # So propagate it to this entry here.
      def detect_tree_value_modification
        return unless entry[:value].is_a?(AugeasTreeValue)
        return if entry[:operation] != :keep

        entry[:operation] = entry[:value].modified? ? :modify : :keep
      end

      # the entries preceding this entry
      def preceding_entries
        return [] if index.zero? # first entry
        tree.all_data[0..(index - 1)]
      end

      # the entries following this entry
      def following_entries
        tree.all_data[(index + 1)..-1]
      end

      # the index of this entry in its tree
      def index
        @index ||= tree.all_data.index(entry)
      end
    end

    # Represents an operation that needs to be done after all modifications.
    #
    # The reason to have this class is that Augeas renumbers its arrays after
    # some operations like `rm` or `insert` so previous paths are no longer
    # valid. For this reason these sensitive operations that change paths need
    # to be done at the end and with careful order.
    # See https://www.redhat.com/archives/augeas-devel/2017-March/msg00002.html
    #
    # @note This class depends on ordered operations. So adding and removing
    # entries has to be done in order how they are placed in tree.
    class LazyOperations
      # @param aug result of Augeas.create
      def initialize(aug)
        @aug = aug
        @operations = []
      end

      def add(located_entry)
        @operations << { type: :add, located_entry: located_entry }
      end

      def remove(located_entry)
        @operations << { type: :remove, path: located_entry.path }
      end

      # starts all previously inserted operations
      def run
        # the reverse order is needed because if there are two operations
        # one after another then the latter cannot affect the former
        @operations.reverse_each do |operation|
          case operation[:type]
          when :remove then aug.rm(operation[:path])
          when :add
            located_entry = operation[:located_entry]
            add_entry(located_entry)
          else
            raise "Invalid lazy operation #{operation.inspect}"
          end
        end
      end

    private

      attr_reader :aug

      # Adds entry to tree. At first it finds where to add it to be in correct
      # place and then sets its value. Recursive if needed. In recursive case
      # it is already known that whole sub-tree is also new and just added.
      def add_entry(located_entry)
        path = insert_entry(located_entry)
        set_new_value(path, located_entry)
      end

      # Sets new value to given path. It is used for values that are not yet in
      # Augeas tree. If needed it does recursive adding.
      # @param path [String] path which can contain Augeas path expression for
      #   key of new value
      # @param located_entry [LocatedEntry] entry to write
      # @see https://github.com/hercules-team/augeas/wiki/Path-expressions
      def set_new_value(path, located_entry)
        aug.set(path, located_entry.entry_value)
        prefix = path[/(^.*)\[[^\]]*\]/, 1] || path
        # we need to get new path as set can look like [last() + 1]
        # which creates new entry and we do not want to add subtree to new
        # entries
        new_path = aug.match(prefix + "[last()]").first
        add_subtree(located_entry.entry_tree, new_path)
      end

      # Adds new subtree. Simplified version of common write as it is known
      # that all entries will be just added.
      # @param tree [CFA::AugeasTree] to add
      # @param prefix [String] prefix where to place *tree*
      def add_subtree(tree, prefix)
        tree.all_data.each do |entry|
          located_entry = LocatedEntry.new(tree, entry, prefix)
          # universal path that handles also new elements for arrays
          path = "#{prefix}/#{located_entry.key}[last()+1]"
          set_new_value(path, located_entry)
        end
      end

      # It inserts a key at given position without setting its value.
      # Its logic is to set it after the last valid entry. If it is not defined
      # then tries to place it before the first valid entry in tree. If there is
      # no entry in tree, then does not insert a position, which means that
      # subsequent setting of value appends it to the end.
      #
      # @param located_entry [LocatedEntry] entry to insert
      # @return [String] where value should be written. Can
      #   contain path expressions.
      #   See https://github.com/hercules-team/augeas/wiki/Path-expressions
      def insert_entry(located_entry)
        # entries with add not exist yet
        preceding = located_entry.preceding_existing
        prefix = located_entry.prefix
        if preceding
          insert_after(preceding, located_entry)
        # entries with remove is already removed, otherwise find previously
        elsif located_entry.any_following?
          aug.insert(prefix + "/*[1]", located_entry.key, true)
          aug.match(prefix + "/*[1]").first
        else
          "#{prefix}/#{located_entry.key}"
        end
      end

      # Insert key after preceding.
      # @see insert_entry
      # @param preceding [LocatedEntry] entry after which the new one goes
      # @param located_entry [LocatedEntry] entry to insert
      # @return [String] where value should be written.
      def insert_after(preceding, located_entry)
        aug.insert(preceding.path, located_entry.key, false)
        paths = aug.match(located_entry.prefix + "/*")
        paths_index = paths.index(preceding.path) + 1
        paths[paths_index]
      end
    end

    attr_reader :aug

    # Does modification according to the operation defined in {AugeasElement}
    # @param located_entry [LocatedEntry] entry to process
    def process_operation(located_entry)
      case located_entry.entry[:operation]
      when :add, nil then @lazy_operations.add(located_entry)
      when :remove then @lazy_operations.remove(located_entry)
      when :modify then modify_entry(located_entry)
      when :keep then recurse_write(located_entry)
      else raise "invalid :operation in #{located_entry.inspect}"
      end
    end

    # Writes value of entry to path and if it has a sub-tree
    # then it calls {#write} on it
    # @param located_entry [LocatedEntry] entry to modify
    def modify_entry(located_entry)
      value = located_entry.entry_value
      aug.set(located_entry.path, value)
      report_error { aug.set(located_entry.path, value) }
      recurse_write(located_entry)
    end

    # calls write on entry if entry have sub-tree
    # @param located_entry [LocatedEntry] entry to recursive write
    def recurse_write(located_entry)
      write(located_entry.path, located_entry.entry_tree, top_level: false)
    end

    # Calls block and if it failed, raise exception with details from augeas
    # why it failed
    # @yield call to aug that is secured
    # @raise [RuntimeError]
    def report_error
      return if yield

      error = aug.error
      # zero is no error, so problem in lense
      if aug.error[:code].nonzero?
        raise "Augeas error #{error[:message]}. Details: #{error[:details]}."
      end

      msg = aug.get("/augeas/text/store/error/message")
      location = aug.get("/augeas/text/store/error/lens")
      raise "Augeas serializing error: #{msg} at #{location}"
    end
  end
end
