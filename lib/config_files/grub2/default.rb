require "config_files/base_model"
require "config_files/augeas_parser"

module ConfigFiles
  module Grub2
    # Represents grub configuration in /etc/default/grub
    # Main features:
    #
    # - Do not overwrite files
    # - When setting value first try to just change value if key already exists
    # - When key is not set, then try to find commented out line with key and
    #   replace it with real config
    # - When even commented out code is not there, then append configuration
    #   to the end of file
    class Default < BaseModel
      PARSER = AugeasParser.new("sysconfig.lns")
      PATH = "/etc/default/grub"

      def initialize(file_handler: File)
        super(PARSER, PATH, file_handler: file_handler)
        self.data = AugeasTree.new
      end

      def save(changes_only: false)
        # serialize kernel params object before save
        if @kernel_params
          generic_set("GRUB_CMDLINE_LINUX_DEFAULT", @kernel_params.serialize)
        end

        super
      end

      def os_prober
        @os_prober ||= BooleanValue.new(
          "GRUB_DISABLE_OS_PROBER",
          self,
          default:     true,
          # grub key is disable, so use reverse logic
          true_value:  "false",
          false_value: "true"
        )
      end

      def kernel_params
        @kernel_params ||= KernelParams.new(data["GRUB_CMDLINE_LINUX_DEFAULT"])
      end

      def disable_recovery_entry
        generic_set("GRUB_DISABLE_RECOVERY", "true")
      end

      def enable_recovery_entry(kernel_params)
        generic_set("GRUB_DISABLE_RECOVERY", "false")
        generic_set("GRUB_CMDLINE_LINUX_RECOVERY", kernel_params)
      end

      def timeout
        data["GRUB_TIMEOUT"] || 10
      end

      def timeout=(value)
        generic_set("GRUB_TIMEOUT", value)
      end

      def cryptodisk
        @cryptodisk ||= BooleanValue.new(
          "GRUB_ENABLE_CRYPTODISK",
          self
        )
      end

      def terminal
        case data["GRUB_TERMINAL"]
        when "console", "", nil
          :console
        when "serial"
          :serial
        when "gfxterm"
          :gfxterm
        else
          raise "unknown GRUB_TERMINAL option #{data["GRUB_TERMINAL"].inspect}"
        end
      end

      VALID_TERMINAL_OPTIONS = [:serial, :console, :gfxterm]
      def terminal=(value)
        if !VALID_TERMINAL_OPTIONS.include?(value)
          raise ArgumentError, "invalid value #{value.inspect}"
        end

        generic_set("GRUB_TERMINAL", value.to_s)
      end

      def serial_console=(value)
        self.terminal = :serial
        generic_set("GRUB_SERIAL_COMMAND", value)
      end

      def serial_console
        data["GRUB_SERIAL_COMMAND"]
      end

      # powerfull low level method that sets any value in grub config.
      # @note prefer to use specialized methods
      def generic_set(key, value)
        modify(key, value) || uncomment(key, value) || add_new(key, value)
      end

      # powerfull method that gets unformatted any value in grub config.
      # @note prefer to use specialized methods
      def generic_get(key)
        data[key]
      end

    private

      def modify(key, value)
        # if already set, just change value
        return false unless data[key]

        data[key] = value
        true
      end

      def uncomment(key, value)
        # Try to find if it is commented out, so we can replace line
        matcher = AugeasMatcher.new(
          collection:    "#comment",
          value_matcher: /#{key}\s*=/
        )
        return false unless  data.data.any?(&matcher)

        data.add(key, value, AugeasReplacePlacer.new(matcher))
        true
      end

      def add_new(key, value)
        data.add(key, value)
      end

      # Representing boolean value switcher in default grub configuration file.
      # Allows easy switching and questioning for boolean value, even if
      # represented by text in config file
      class BooleanValue
        def initialize(name, model, default: false,
                        true_value: "true", false_value: "false"
                      )
          @name = name
          @model = model
          @default = default
          @true_value = true_value
          @false_value = false_value
        end

        def enable
          @model.generic_set(@name, @true_value)
        end

        def disable
          @model.generic_set(@name, @false_value)
        end

        def enabled?
          return @default unless data

          data == @true_value
        end

        def disabled?
          return @default unless data

          data != @true_value
        end

        # sets boolean value, recommend to use for generic boolean setter.
        # for constants prefer to use enable/disable
        def value=(value)
          @model.generic_set(@name, value ? @true_value : @false_value)
        end

      private

        def data
          @model.generic_get(@name)
        end
      end

      # Represents kernel append line with helpers to easier modification.
      # TODO: handle quoting, maybe have own lense to parse/serialize kernel
      #       params?
      class KernelParams
        def initialize(line)
          @tree = ParamTree.new(line)
        end

        def serialize
          @tree.to_string
        end

        # gets value for parameters.
        # @return possible values are `false` when parameter missing,
        #   `true` when parameter without value placed, string if single
        #   instance with value is there and array if multiple instance with
        #   values are there.
        #
        # @example different values
        #   line = "quite console=S0 console=S1 vga=0x400"
        #   params = KernelParams.new(line)
        #   params.parameter("quite") # => true
        #   params.parameter("verbose") # => false
        #   params.parameter("vga") # => "0x400"
        #   params.parameter("console") # => ["S0", "S1"]
        #
        def parameter(key)
          values = @tree.data.select{ |e| e[:key] == key }.map{ |e| e[:value] }
          if values.empty?
            false
          elsif values.size > 1
            values
          elsif values.first == true
            true
          else
            values.first
          end
        end

        # Adds new parameter to kernel command line. Uses augeas placers.
        # To replace value use {AugeasReplacePlacer}
        def add_parameter(key, value, placer = AugeasAppendPlacer.new)
          element = placer.new_element(@tree)

          element[:key]   = key
          element[:value] = value
        end

        # Removes parameter from kernel command line.
        # @param matcher [AugeasMatcher] to find entry to remove
        def remove_parameter(matcher)
          @tree.data.reject!(&matcher)
        end

        # TODO replace it via augeas parser when someone write lense
        class ParamTree
          attr_reader :data

          def initialize(line)
            line ||= ""
            pairs = line.split(/\s/).reject(&:empty?).map {|e| e.split("=", 2)}
            @data = pairs.map do |k, v|
              {
                key:   k,
                value: v || true, # kernel param without value have true
              }
            end
          end

          def to_string
            snippets = @data.map do |e|
              if e[:value] == true
                e[:key]
              else
                "#{e[:key]}=#{e[:value]}"
              end
            end

            snippets.join(" ")
          end
        end
      end
    end
  end
end
