require "config_files/base_model"
require "config_files/augeas_parser"

module ConfigFiles
  PARSER = AugeasParser.new("sysconfig.lns")
  PATH = "/etc/default/grub"

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
      data["GRUB_DISABLE_OS_PROBER"] = "true"
    end

    def enable_os_prober
      data["GRUB_DISABLE_OS_PROBER"] = "false"
    end

    def disable_recovery_entry
      data["GRUB_DISABLE_RECOVERY"] = "true"
    end

    def enable_recovery_entry(kernel_params)
      data["GRUB_DISABLE_RECOVERY"] = "false"
      data["GRUB_CMDLINE_LINUX_RECOVERY"] = kernel_params
    end
  end
end
