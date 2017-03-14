module CFA
  # Goal of this class is to write back to augeas data stored in {AugeasTree}.
  # It tries to only required changes, as augeas keeps inside flag if it is
  # modified and if not modified, then part of file is kept untouched.
  # @note internal only, unstable API
  # @private
  class AugeasWriter
    # @param aug result of Augeas.create
    def initialize(aug)
      @aug = aug
    end

    # write to augeas data in tree to given prefix
    # @param prefix [String] where to write tree in augeas
    # @param tree [CFA::AugeasTree] tree to write
    def write(prefix, tree, top_level: true)
      reset_lazy_operations if top_level
      last_valid_entry_path = nil
      tree.data(filtered: false).each do |entry|
        key, path = key_and_path(tree, entry, prefix)
        process_operation(tree, entry, last_valid_entry_path, key, path, prefix)
        last_valid_entry_path = path if entry[:operation] != :remove
      end
      do_lazy_operations if top_level
    end

  private

    attr_reader :aug

    # returns available number for given collection that can be used to write
    # @param tree [CFA::AugeasTree] tree where collection is defined
    # @param key [String] collection name
    def new_array_number(tree, key)
      all_elements = tree.data(filtered: false)
                         .select { |e| e[:key] == key }
      nums = all_elements.map do |entry|
        entry[:orig_key] ? entry[:orig_key][/^.*\[(\d+)\]$/, 1].to_i : 0
      end
      nums.max ? (nums.max + 1) : 1
    end

    # construct augeas key and whole path where to write for collection
    def key_and_path_array(tree, entry, prefix)
      if entry[:orig_key]
        key = entry[:orig_key]
      else
        strip_key = entry[:key]
        key = strip_key[0..-2] + new_array_number(tree, strip_key).to_s + "]"
      end
      path = prefix + "/" + key
      [key, path]
    end

    # construct augeas key and whole path where to write
    def key_and_path(tree, entry, prefix)
      if entry[:key].end_with?("[]")
        key_and_path_array(tree, entry, prefix)
      else
        [entry[:key], prefix + "/" + entry[:key]]
      end
    end


    # do lazy removing. Reason for doing this is collections.
    # After each aug.rm it is renumbered, which is problem as later it will
    # remove wrong entry. so we remove it in reverse order, which ignore
    # numbering.
    def lazy_remove(path)
      @lazy_operations << { type: :remove, path: path }
    end

    # adds also need to be added lazy due to renumbering of elements in array
    # see https://www.redhat.com/archives/augeas-devel/2017-March/msg00002.html
    def lazy_add(tree, value, index, prefix)
      @lazy_operations << { type: :add, tree: tree, value: value, index: index, prefix: prefix }
    end

    # clears list of pathgs to remove
    def reset_lazy_operations
      @lazy_operations = []
    end

    # does lazy operations of nodes. For reasons see #lazy_remove and #lazy_add
    def do_lazy_operations
      # reverse order is needed, because if there is two consequest operations,
      # then later one cannot affect earlier one
      @lazy_operations.reverse.each do |operation|
        case operation[:type]
        when :remove then report_error { aug.rm(operation[:path]) }
        when :add
          path = insert_entry(operation[:tree], operation[:index], operation[:prefix])
          set_new_value(path, operation[:value])
        else
          raise "Invalid lazy operation #{operation.inspect}"
        end
      end
    end

    def set_new_value(path, value)
      case value
      when AugeasTree
        aug.touch(path)
        add_subtree(value, path)
      when AugeasTreeValue
        report_error { aug.set(path, value.value) }
        add_subtree(value.tree, path)
      else
        report_error { aug.set(path, value) }
      end
    end

    def add_subtree(tree, prefix)
      tree.data(filtered: false).each do |entry|
        key = entry[:key]
        key = key[0..-3] if key.end_with?("[]")
        # universal path that handle also new elements for arrays
        path = "#{prefix}/#{key}[last()+1]"
        set_new_value(path, entry[:value])
      end
    end

    # It inserts a key at given position without setting its value.
    # Its logic is to set it after last valid entry. If it is not defined
    # then try to place it before first valid entry in tree. If there is
    # no entry in tree, then do not insert position, which means, that
    # following setting of value appends it to the end.
    #
    # @param last [String] path of last valid entry written to tree
    # @param key [String] key that need to be inserted
    # @param tree [CFA::AugeasTree] tree where is key located
    def insert_entry(tree, index, prefix)
      # entries with add not exist yet
      last_existing = tree.data(filtered: false)[0..(index - 1)].rindex { |e| e[:operation] != :add }
      entry = tree.data(filtered: false)[index]
      key = entry[:key]
      key = key[0..-3] if key.end_with?("[]")
      if last_existing
        last_path = prefix + "/" + tree.data(filtered: false)[last_existing][:orig_key]
        aug.insert(last_path, key, false)
        paths = aug.match(prefix + "/*")
        paths_index = paths.index(last_path) + 1
        return paths[paths_index]
      else
        # entries with remove is already removed, otherwise find previously
        any_surviving = tree.data(filtered: false)[(index+1)..-1].any? { |e| e[:operation] != :remove }
        if any_surviving
          aug.insert(prefix+"/*[1]", key, true)
          return aug.match(prefix + "/*[1]")
        else
          return "#{prefix}/#{key}"
        end
      end
    end


    # Do modification according to operation defined in AugeasEntry
    # @param tree [CFA::AugeasTree] tree where entry lives
    # @param entry [AugeasElement] entry to process
    # @param last_valid_entry_path [String, nil] path of last valid entry
    #   written or nil if there is no such entry
    # @param key [String] valid augeas key for entry. Important for collections
    #   which have key without its index, but augeas do not allow it.
    # @param path [String] whole path where to write entry in augeas
    def process_operation(tree, entry,
      last_valid_entry_path, key, path, prefix)
      case entry[:operation]
      when :add, nil # add is default operation
        lazy_add(tree, entry[:value], tree.data(filtered: false).index(entry), prefix)
      when :remove then lazy_remove(path)
      when :modify then set_entry(path, entry)
      when :keep then recurse_write(path, entry)
      else raise "invalid :operation in #{entry.inspect}"
      end
    end

    # writes value of entry to path and if it have sub-tree then call {write} on it
    # @param path [String] path where to write
    # @param entry [AugeasElement] entry to write
    def set_entry(path, entry)
      value = entry[:value]
      case value
      when AugeasTree
        report_error { aug.touch(path) }
      when AugeasTreeValue
        report_error { aug.set(path, value.value) }
      else
        report_error { aug.set(path, value) }
      end
      recurse_write(path, entry)
    end

    # calls write on entry if entry have sub-tree
    # @param path [String] path of entry
    # @param entry [AugeasElement]
    def recurse_write(path, entry)
      if entry[:value].is_a?(AugeasTree)
        write(path, entry[:value], top_level: false)
      elsif entry[:value].is_a?(AugeasTreeValue)
        write(path, entry[:value].tree, top_level: false)
      end
    end

    # Finds first entry that is already in augeas, so it means entry,
    # that is kept or only modified
    def find_first_surviving(data)
      data.find { |e| [:keep, :modify].include?(e[:operation]) }
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
