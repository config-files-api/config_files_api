# typed: strong

module CFA
  class AugeasError < RuntimeError
  end

  class AugeasInternalError < AugeasError
    attr_reader :details
    attr_reader :aug_message

    sig {params(message: String, details: T.untyped).void}
    def initialize(message, details)
      @aug_message = message
      @details = details
    end
  end

  # Parsing error
  class AugeasParsingError < AugeasError
    attr_reader :aug_message
    attr_reader :file
    attr_reader :line
    attr_reader :character
    attr_reader :lens
    attr_reader :file_content

    sig do
      params(
        params: {
          message: String,
          file: String,
          line: Integer,
          char: Integer,
          lens: String,
          file_content: String
        }
      ).void
    end
    def initialize(params)
    end
  end

  # Serializing error
  class AugeasSerializingError < AugeasError
    attr_reader :aug_message
    attr_reader :file
    attr_reader :lens
    attr_reader :aug_tree

    sig do
      params(
        params: {
          message: String,
          file: String,
          lens: String,
          aug_tree: T.untyped
          
        }
      ).void
    end
    def initialize(params)
    end
  end

  # Represents list of same config options in augeas.
  # For example comments are often stored in collections.
  class AugeasCollection
    extend Forwardable
    def initialize(tree, name)
      @tree = tree
      @name = name
    end

    def_delegators :@collection, :[], :empty?, :each, :map, :any?, :all?, :none?

    def add(value, placer = AppendPlacer.new)
    end

    def delete(value)
    end

  private

    def load_collection
    end

    def augeas_name
    end

    def to_remove(value)
    end

    def value_match?(value, match)
    end
  end

  # Represents a node that contains both a value and a subtree below it.
  # For easier traversal it forwards `#[]` to the subtree.
  class AugeasTreeValue
    # @return [String] the value in the node
    attr_reader :value
    # @return [AugeasTree] the subtree below the node
    attr_accessor :tree

    sig {params(tree: T.untyped, value: T.untyped).void}
    def initialize(tree, value)
    end

    # (see AugeasTree#[])
    def [](key)
    end

    sig {params(value: T.untyped).returns(TrueClass)}
    def value=(value)
    end

    sig {params(other: BasicObject).returns(T::Boolean)}
    def ==(other)
    end

    # @return true if the value has been modified
    def modified?
    end

    # For objects of class Object, eql? is synonymous with ==:
    # http://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==
  end

  # Represents a parsed Augeas config tree with user friendly methods
  class AugeasTree
    def data
    end

    # low level access to all AugeasElement including ones marked for removal
    def all_data
    end

    sig {void}
    def initialize
    end

    # Gets new unique id in numberic sequence. Useful for augeas models that
    # using sequences like /etc/hosts . It have keys like "1", "2" and when
    # adding new one it need to find new key.
    def unique_id
    end

    # @return [AugeasCollection] collection for *key*
    sig {params(key: T.untyped).returns(CFA::AugeasCollection)}
    def collection(key)
    end

    # @param [String, Matcher] matcher
    def delete(matcher)
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
    end

    # Finds given *key* in tree.
    # @param key [String]
    # @return [String,AugeasTree,AugeasTreeValue,nil] the first value for *key*,
    #   or `nil` if not found
    def [](key)
    end

    def []=(key, value)
    end

    sig {params(matcher: T::Array[IO]).returns(T::Array[String])}
    def select(matcher)
    end

    sig {params(other: BasicObject).returns(T::Boolean)}
    def ==(other)
    end

    # For objects of class Object, eql? is synonymous with ==:
    # http://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==

  private

    sig {params(old_entry: T.untyped).returns(T::Hash[T.untyped, T.untyped])}
    def replace_entry(old_entry)
    end

    def mark_new_entry(new_entry, old_entry)
    end

    def entry_to_modify(key, value)
    end
  end

  class AugeasParser
    # @return [String] optional, used for error reporting
    attr_accessor :file_name

    # @param lens [String] a lens name, like "Sysconfig.lns"
    sig {params(lens: T.untyped).void}
    def initialize(lens)
    end

    # @param raw_string [String] a string to be parsed
    # @return [AugeasTree] the parsed data
    def parse(raw_string)
    end

    # @param data [AugeasTree] the data to be serialized
    # @return [String] a string to be written
    def serialize(data)
    end

    # @return [AugeasTree] an empty tree that can be filled
    #   for future serialization
    sig {returns(CFA::AugeasTree)}
    def empty
    end

  private

    # @param aug [::Augeas]
    # @param activity [:parsing, :serializing] for better error messages
    # @param file_name [String,nil] a file name
    # @param data [AugeasTree, String] used data so augeas tree for
    #   serializing or file content for parsing
    sig {params(aug: T.untyped, activity: T.untyped, file_name: T.untyped, data: T.untyped).void}
    def report_error(aug, activity, file_name, data = nil)
    end

    sig {params(aug: T.untyped).returns(NilClass)}
    def report_internal_error!(aug)
    end

    sig {params(args: T.untyped, activity: T.untyped, data: T.untyped).void}
    def report_activity_error!(args, activity, data)
    end

    sig {params(aug: T.untyped).returns(T::Hash[T.untyped, T.untyped])}
    def aug_get_error(aug)
    end
  end
end
