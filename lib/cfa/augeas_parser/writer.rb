module CFA
  # Smart writer trying to do as less modification as possible.
  # @note internal only, unstable API
  class AugeasWriter
    def initialize(aug)
      @aug = aug
    end

    def write(prefix, tree)
      last_valid_entry_path = nil
      tree.data(filtered: false).each do |entry|
        key, path = key_and_value(tree, entry, prefix)
        process_operation(tree, entry, last_valid_entry_path, key, path)
        last_valid_entry_path = path if entry[:operation] != :remove
      end
    end

  private

    attr_reader :aug

    def new_array_number(tree, key)
      all_elements = tree.data(filtered: false)
                         .select { |e| e[:key] == key }
      nums = all_elements.map do |entry|
        entry[:orig_key] ? entry[:orig_key][/^.*\[(\d+)\]$/, 1].to_i : 0
      end
      nums.max ? (nums.max + 1) : 1
    end

    def key_and_value_array(tree, entry, prefix)
      if entry[:orig_key]
        key = entry[:orig_key]
      else
        strip_key = entry[:key]
        key = strip_key[0..-2] + new_array_number(tree, strip_key).to_s + "]"
      end
      path = prefix + "/" + key
      [key, path]
    end

    def key_and_value(tree, entry, prefix)
      if entry[:key].end_with?("[]")
        key_and_value_array(tree, entry, prefix)
      else
        [entry[:key], prefix + "/" + entry[:key]]
      end
    end

    def insert_entry(last, key, tree)
      if last
        report_error { aug.insert(last, key, false) }
      else
        e = find_first_valid(tree.data(filtered: false))
        if e
          e_path = prefix + "/" + e[:orig_key]
          report_error { aug.insert(e_path, key, true) }
        end
      end
    end

    def process_operation(tree, entry,
      last_valid_entry_path, key, path)
      case entry[:operation]
      when :add, nil # add is default operation
        insert_entry(last_valid_entry_path, key, tree)
        set_entry(path, entry)
      when :remove then report_error { aug.rm(path) }
      when :modify then set_entry(path, entry[:value])
      when :keep then recurse_write(path, entry)
      else raise "invalid operation"
      end
    end

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

    def recurse_write(path, entry)
      if entry[:value].is_a?(AugeasTree)
        write(path, entry[:value])
      elsif entry[:value].is_a?(AugeasTreeValue)
        write(path, entry[:value].tree)
      end
    end

    def find_first_valid(data)
      data.find { |e| [:keep, :modify].include?(e[:operation]) }
    end

    def report_error
      return if yield

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
