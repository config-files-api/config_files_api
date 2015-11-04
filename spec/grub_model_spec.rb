require_relative "spec_helper"
require "config_files/grub2/default"
require "config_files/memory_file"

describe ConfigFiles::Grub2::Default do
  let(:boolean_value_class) { ConfigFiles::Grub2::Default::BooleanValue }
  let(:memory_file) { ConfigFiles::MemoryFile.new(file_content) }
  let(:config) do
    res = ConfigFiles::Grub2::Default.new(file_handler: memory_file)
    res.load
    res
  end

  describe "#os_prober" do
    let(:file_content) { "GRUB_DISABLE_OS_PROBER=true\n" }

    it "returns object representing boolean state" do
      expect(config.os_prober).to be_a(boolean_value_class)
      # few simple test to verify params
      expect(config.os_prober.enabled?).to eq(false)

      # and store test
      config.os_prober.enable
      config.save
      expect(memory_file.content).to eq("GRUB_DISABLE_OS_PROBER=false\n")
    end
  end

  describe "#cryptodisk" do
    let(:file_content) { "GRUB_ENABLE_CRYPTODISK=false\n" }

    it "returns object representing boolean state" do
      expect(config.os_prober).to be_a(boolean_value_class)
      # few simple test to verify params
      expect(config.cryptodisk.enabled?).to eq(false)

      # and store test
      config.cryptodisk.enable
      config.save
      expect(memory_file.content).to eq("GRUB_ENABLE_CRYPTODISK=true\n")
    end
  end

  describe "#generic_set" do
    context "value is already specified in file" do
      let(:file_content) { "GRUB_ENABLE_CRYPTODISK=false\n" }

      it "modify line" do
        config.generic_set("GRUB_ENABLE_CRYPTODISK", "true")
        config.save

        expect(memory_file.content).to eq("GRUB_ENABLE_CRYPTODISK=true\n")
      end
    end

    context "key is commented out in file" do
      let(:file_content) { "#bla bla\n#GRUB_ENABLE_CRYPTODISK=false\n" }

      it "uncomment and modify line" do
        config.generic_set("GRUB_ENABLE_CRYPTODISK", "true")
        config.save

        # TODO: check why augeas sometimes espace and sometimes not
        expected_content = "#bla bla\nGRUB_ENABLE_CRYPTODISK=\"true\"\n"
        expect(memory_file.content).to eq(expected_content)
      end
    end

    context "key is missing in file" do
      let(:file_content) { "" }

      it "inserts line" do
        config.generic_set("GRUB_ENABLE_CRYPTODISK", "true")
        config.save

        # TODO: check why augeas sometimes espace and sometimes not
        expect(memory_file.content).to eq("GRUB_ENABLE_CRYPTODISK=\"true\"\n")
      end
    end
  end
end
