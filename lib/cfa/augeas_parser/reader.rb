require "cfa/augeas_parser/keys_cache"
require "cfa/augeas_parser"

module CFA
  # A class responsible for reading {AugeasTree} from Augeas
  class AugeasReader
    class << self
      # Creates *tree* from *prefix* in *aug*.
      # @param aug [::Augeas]
      # @param prefix [String] Augeas path prefix
      # @return [AugeasTree]
      def read(aug, prefix)
        keys_cache = AugeasKeysCache.new(aug, prefix)

        tree = AugeasTree.new
        load_tree(aug, prefix, tree, keys_cache)

        tree
      end

    private

      # fills *tree* with data
      def load_tree(aug, prefix, tree, keys_cache)
        data = keys_cache.keys_for_prefix(prefix).map do |key|
          aug_key = prefix + "/" + key
          {
            key:       load_key(prefix, aug_key),
            value:     load_value(aug, aug_key, keys_cache),
            orig_key:  stripped_path(prefix, aug_key),
            operation: :keep
          }
        end

        tree.all_data.concat(data)
      end

      # loads a key in a format that AugeasTree expects
      def load_key(prefix, aug_key)
        # clean from key prefix and for collection remove number inside []
        # +1 for size due to ending '/' not part of prefix
        key = stripped_path(prefix, aug_key)
        key.end_with?("]") ? key.sub(/\[\d+\]$/, "[]") : key
      end

      # path without prefix we are not interested in
      def stripped_path(prefix, aug_key)
        aug_key[(prefix.size + 1)..-1]
      end

      # loads value from auges. If value have tree under, it will also read it
      def load_value(aug, aug_key, keys_cache)
        subkeys = keys_cache.keys_for_prefix(aug_key)

        nested = !subkeys.empty?
        value = aug.get(aug_key)
        if nested
          subtree = AugeasTree.new
          load_tree(aug, aug_key, subtree, keys_cache)
          value ? AugeasTreeValue.new(subtree, value) : subtree
        else
          value
        end
      end
    end
  end
end
