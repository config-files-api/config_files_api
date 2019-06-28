# typed: strict

module CFA
  class AugeasWriter
    def initialize(aug)
    end

    def write(prefix, tree, top_level: true)
    end

  private

    class LocatedEntry
      attr_reader :prefix
      attr_reader :entry
      attr_reader :tree

      def initialize(tree, entry, prefix)
      end

      def orig_key
      end

      def path
      end

      def key
      end

      def preceding_existing
      end

      def any_following?
      end

      def entry_tree
      end

      def entry_value
      end

    private

      def detect_tree_value_modification
      end

      def preceding_entries
      end

      def following_entries
      end

      def index
      end
    end

    class LazyOperations
      def initialize(aug)
      end

      def add(located_entry)
      end

      def remove(located_entry)
      end

      def run
      end

    private

      attr_reader :aug

      def remove_entry(path)
      end

      def path_to_remove(path)
      end

      def add_entry(located_entry)
      end

      def set_new_value(path, located_entry)
      end

      def add_subtree(tree, prefix)
      end

      def insert_entry(located_entry)
      end

      def insert_after(preceding, located_entry)
      end

      def path_after(preceding)
      end
    end

    attr_reader :aug

    def process_operation(located_entry)
    end

    def modify_entry(located_entry)
    end

    def recurse_write(located_entry)
    end

    def report_error
    end
  end
end
