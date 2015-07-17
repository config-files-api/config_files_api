require "config_files/base_model"
require "config_files/augeas_parser"

module ConfigFiles
  PARSER = AugeasParser.new("sysconfig.lns")
  PATH = "/etc/default/grub"

  # Represents grub configuration in /etc/default/grub
  # Main features:
  # - Do not overwrite files
  # - When setting value first try to just change value if key already exists
  # - When key is not set, then try to find commented out line with key and replace it with real config
  # - When even commented out code is not there, then append configuration to the end of file
  class GrubModel < BaseModel
    def initialize(file_class: File)
      super(PARSER, PATH, file_class: file_class)
      self.data = AugeasTree.new
    end

    def os_prober_enabled?
      return true unless data["GRUB_DISABLE_OS_PROBER"]
      return data["GRUB_DISABLE_OS_PROBER"] != "true"
    end

    def disable_os_prober
      set_value("GRUB_DISABLE_OS_PROBER", "true")
    end

    def enable_os_prober
      set_value("GRUB_DISABLE_OS_PROBER", "false")
    end

    def disable_recovery_entry
      set_value("GRUB_DISABLE_RECOVERY", "true")
    end

    def enable_recovery_entry(kernel_params)
      set_value("GRUB_DISABLE_RECOVERY", "false")
      set_value("GRUB_CMDLINE_LINUX_RECOVERY", kernel_params)
    end

  private
    def set_value(key, value)
      # if already set, just change value
      if data[key]
        data[key] = value
        return
      end
      # Try to find if it is commented out, so we can replace line
      matcher = AugeasMatcher.new(collection: "#comment", value_matcher: /#{key}\s*=/)
      if data.data.any?(&matcher)
        data.add(key, value, AugeasReplacePlacer.new(matcher))
        return
      end

      # no even commented out, so lets just place it to the end
      data.add(key, value)
    end
  end
end
