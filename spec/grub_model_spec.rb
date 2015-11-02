require_relative "spec_helper"
require "config_files/grub2/default"
require "config_files/memory_file"

describe ConfigFiles::Grub2::Default do
  describe "#os_prober" do
    it "returns object representing boolean state" do
      memory_file = ConfigFiles::MemoryFile.new("GRUB_DISABLE_OS_PROBER=true\n")
      config = ConfigFiles::Grub2::Default.new(file_class: memory_file)
      config.load
      expect(config.os_prober).to be_a(ConfigFiles::Grub2::Default::BooleanValue)
      # few simple test to verify params
      puts config.send(:data)["GRUB_DISABLE_OS_PROBER"]
      expect(config.os_prober.enabled?).to eq(false)

      # and store test
      config.os_prober.enable
      config.save
      expect(memory_file.content).to eq("GRUB_DISABLE_OS_PROBER=false\n")
    end
  end

  describe "#cryptodisk" do
    it "returns object representing boolean state" do
      memory_file = ConfigFiles::MemoryFile.new("GRUB_ENABLE_CRYPTODISK=false\n")
      config = ConfigFiles::Grub2::Default.new(file_class: memory_file)
      config.load
      expect(config.os_prober).to be_a(ConfigFiles::Grub2::Default::BooleanValue)
      # few simple test to verify params
      puts config.send(:data)["GRUB_ENABLE_CRYPTODISK"]
      expect(config.cryptodisk.enabled?).to eq(false)

      # and store test
      config.cryptodisk.enable
      config.save
      expect(memory_file.content).to eq("GRUB_ENABLE_CRYPTODISK=true\n")
    end
  end

  describe "#generic_set" do
    it "modify already existing value" do
      memory_file = ConfigFiles::MemoryFile.new("GRUB_ENABLE_CRYPTODISK=false\n")
      config = ConfigFiles::Grub2::Default.new(file_class: memory_file)
      config.load

      config.generic_set("GRUB_ENABLE_CRYPTODISK", "true")
      config.save

      expect(memory_file.content).to eq("GRUB_ENABLE_CRYPTODISK=true\n")
    end

    it "uncomment and modify commented out value if real one doesn't exist" do
      memory_file = ConfigFiles::MemoryFile.new("#bla bla\n#GRUB_ENABLE_CRYPTODISK=false\n")
      config = ConfigFiles::Grub2::Default.new(file_class: memory_file)
      config.load

      config.generic_set("GRUB_ENABLE_CRYPTODISK", "true")
      config.save

      # TODO: check why augeas sometimes espace and sometimes not
      expect(memory_file.content).to eq("#bla bla\nGRUB_ENABLE_CRYPTODISK=\"true\"\n")
    end

    it "inserts option if neither previous or commented one found" do
      memory_file = ConfigFiles::MemoryFile.new("")
      config = ConfigFiles::Grub2::Default.new(file_class: memory_file)
      config.load

      config.generic_set("GRUB_ENABLE_CRYPTODISK", "true")
      config.save

      # TODO: check why augeas sometimes espace and sometimes not
      expect(memory_file.content).to eq("GRUB_ENABLE_CRYPTODISK=\"true\"\n")
    end
  end

end
