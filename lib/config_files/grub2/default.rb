require "config_files/base_model"
require "config_files/augeas_parser"

module ConfigFiles::Grub2
  # Represents grub configuration in /etc/default/grub
  # Main features:
  # - Do not overwrite files
  # - When setting value first try to just change value if key already exists
  # - When key is not set, then try to find commented out line with key and replace it with real config
  # - When even commented out code is not there, then append configuration to the end of file
  class Default < ConfigFiles::BaseModel
    PARSER = ConfigFiles::AugeasParser.new("sysconfig.lns")
    PATH = "/etc/default/grub"

    def initialize(file_class: File)
      super(PARSER, PATH, file_class: file_class)
      self.data = ConfigFiles::AugeasTree.new
    end

    def os_prober
      @os_prober ||= BooleanValue.new(
        "GRUB_DISABLE_OS_PROBER",
        self,
        default: true,
        # grub key is disable, so use reverse logic
        true_value: "false",
        false_value: "true"
      )
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
      when "console","",nil
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

    def serial_console=(value)
      data["GRUB_SERIAL_COMMAND"]
    end

    # powerfull low level method that sets any value in grub config.
    # @note prefer to use specialized methods
    def generic_set(key, value)
      # if already set, just change value
      if data[key]
        data[key] = value
        return
      end
      # Try to find if it is commented out, so we can replace line
      matcher = ConfigFiles::AugeasMatcher.new(collection: "#comment", value_matcher: /#{key}\s*=/)
      if data.data.any?(&matcher)
        data.add(key, value, ConfigFiles::AugeasReplacePlacer.new(matcher))
        return
      end

      # no even commented out, so lets just place it to the end
      data.add(key, value)
    end

    # powerfull method that gets unformatted any value in grub config.
    # @note prefer to use specialized methods
    def generic_get(key)
      data[key]
    end

    class BooleanValue
      def initialize(name, model, default: false, true_value: "true", false_value: "false")
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
        @model.generic_get("GRUB_DISABLE_OS_PROBER")
      end
    end
  end
end
