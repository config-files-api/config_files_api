# typed: strong
# frozen_string_literal: true

require "cfa/matcher"
require "cfa/placer"
# FIXME: tree should be generic and not augeas specific,
# not needed in 1.0 as planned
require "cfa/augeas_parser"
require "sorbet-runtime"

module CFA
  # A base class for models. Represents a configuration file as an object
  # with domain-specific attributes/methods. For persistent storage,
  # use load and save,
  # Non-responsibilities: actual storage and parsing (both delegated).
  # There is no caching involved.
  class BaseModel
    # @param parser [.parse, .serialize, .empty] parser that can convert object
    #   to string and vice versa. It have to provide methods
    #   `string #serialize(object)`, `object #parse(string)` and `object #empty`
    #   For example see {CFA::AugeasParser}
    # @param file_path [String] expected path passed to file_handler
    # @param file_handler [.read, .write] an object able to read/write a string.
    #   It has to provide methods `string read(string)` and
    #   `write(string, string)`. For an example see {CFA::MemoryFile}.
    #   If unspecified or `nil`, {.default_file_handler} is asked.
    def initialize(parser, file_path, file_handler: nil)
    end

    # Serializes *data* using *parser*
    # and writes the resulting String using *file_handler*.
    # @return [void]
    # @raise a *file_handler* specific error if *file_path* cannot be written
    #   e.g. due to missing permissions or living on a read only device.
    # @raise a *parser* specific error. If *data* contain invalid values
    #   then *parser* may raise an error.
    #   A properly written BaseModel subclass should prevent that by preventing
    #   insertion of such values in the first place.
    def save
    end

    # Reads a String using *file_handler*
    # and parses it with *parser*, storing the result in *data*.
    # @return [void]
    # @raise a *file_handler* specific error. If *file_path* does not exist
    #   or permission is not sufficient it may raise an error
    #   depending on the used file handler.
    # @raise a *parser* specific error. If the parsed String is malformed, then
    #   depending on the used parser it may raise an error.
    sig {returns(T::Boolean)}
    def load
    end

    # powerfull method that sets any value in config. It try to be
    # smart to at first modify existing value, then replace commented out code
    # and if even that doesn't work, then append it at the end
    # @note prefer to use specialized methods of children
    def generic_set(key, value, tree = data)
    end

    # powerfull method that gets unformatted any value in config.
    # @note prefer to use specialized methods of children
    def generic_get(key, tree = data)
    end

    # Returns if configuration was already loaded
    def loaded?
    end

    # Gets default file handler used when nil passed as file_handler in
    # constructor
    def self.default_file_handler
    end

    class << self
      # @param value for value specification see constructor
      attr_writer :default_file_handler
    end

    # Generates accessors for trivial key-value attributes
    # @param attrs [Hash{Symbol => String}] mapping of methods to file keys
    #
    # @example Usage
    #   class FooModel < CFA::BaseModel
    #     attributes(
    #       server:        "server",
    #       read_timeout:  "ReadTimeout",
    #       write_timeout: "WriteTimeout"
    #     )
    #     ...
    #   end
    def self.attributes(attrs)
    end

  protected

    def tree_value_plain(value)
    end

    def tree_value_change(key, value)
    end

    attr_accessor :data

    # Modify an **existing** entry and return `true`,
    # or do nothing and return `false`.
    # @return [Boolean]
    sig {params(key: T.untyped, value: T.untyped, tree: T.untyped).returns(T::Boolean)}
    def modify(key, value, tree)
    end

    # Replace a commented out entry and return `true`,
    # or do nothing and return `false`.
    # @return [Boolean]
    sig {params(key: T.untyped, value: T.untyped, tree: T.untyped).returns(T::Boolean)}
    def uncomment(key, value, tree)
    end

    def add_new(key, value, tree)
    end
  end

  # Represents a boolean value switcher in default grub configuration file.
  # Allows easy switching and questioning for boolean value, even if
  # represented by text in config file.
  # It's tristate: if unset, {#enabled?} and {#disabled?} return `nil`
  # (but once set, we cannot return to an unset state).
  class BooleanValue
    # @param name [String]
    # @param model [BaseModel]
    # @param true_value [String]
    # @param false_value [String]
    def initialize(name, model, true_value: "true", false_value: "false")
    end

    # Set to *true*
    def enable
    end

    # Set to *false*
    def disable
    end

    # @return [Boolean,nil] true, false, (nil if undefined)
    def enabled?
    end

    # @return [Boolean,nil] true, false, (nil if undefined)
    def disabled?
    end

    # @return [Boolean]
    #   true if the key has a value;
    #   false if {#enabled?} and {#disabled?} return `nil`.
    def defined?
    end

    # sets boolean value, recommend to use for generic boolean setter.
    # for constants prefer to use enable/disable
    # @param value [Boolean]
    def value=(value)
    end

    # enhanced inspect method to contain important data
    sig {returns(String)}
    def inspect
    end

    # also have better to_s
    alias_method :to_s, :inspect

  private

    def data
    end
  end
end
