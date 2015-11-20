require_relative "spec_helper"
require "config_files/grub2/default"
require "config_files/memory_file"

describe ConfigFiles::Grub2::Default do
  let(:boolean_value_class) { ConfigFiles::BooleanValue }
  let(:memory_file) { ConfigFiles::MemoryFile.new(file_content) }
  let(:config) do
    res = ConfigFiles::Grub2::Default.new(file_handler: memory_file)
    res.load
    res
  end

  describe "#timeout" do
    context "key is specified" do
      let(:file_content) { "GRUB_TIMEOUT=10\n" }
      it "returns value of GRUB_TIMEOUT key" do
        expect(config.timeout).to eq "10"
      end
    end

    context "key is missing in file" do
      let(:file_content) { "\n" }
      it "returns nil" do
        expect(config.timeout).to eq nil
      end
    end
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

  describe "#kernel_params" do
    let(:file_content) do
      "GRUB_CMDLINE_LINUX_DEFAULT=\"quite console=S0 console=S1 vga=0x400\"\n"
    end

    it "returns KernelParams object" do
      kernel_params_class = ConfigFiles::Grub2::Default::KernelParams
      expect(config.kernel_params).to be_a(kernel_params_class)

      params = config.kernel_params
      expect(params.parameter("quite")).to eq true
      expect(params.parameter("verbose")).to eq false
      expect(params.parameter("vga")).to eq "0x400"
      expect(params.parameter("console")).to eq ["S0", "S1"]

      # lets place verbose after parameter "quite"
      matcher = ConfigFiles::Matcher.new(key: "quite")
      placer = ConfigFiles::AfterPlacer.new(matcher)
      params.add_parameter("verbose", true, placer)

      # lets place silent at the end
      params.add_parameter("silent", true)

      # lets change second console parameter from S1 to S2
      matcher = ConfigFiles::Matcher.new(
        key:           "console",
        value_matcher: "S1"
      )
      placer = ConfigFiles::ReplacePlacer.new(matcher)
      params.add_parameter("console", "S2", placer)

      # lets remove VGA parameter
      matcher = ConfigFiles::Matcher.new(key: "vga")
      params.remove_parameter(matcher)

      config.save
      expected_line = "GRUB_CMDLINE_LINUX_DEFAULT=" \
        "\"quite verbose console=S0 console=S2 silent\"\n"
      expect(memory_file.content).to eq(expected_line)
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
