# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "spec_helper"
require "cfa/vendor_loader"
require "cfa/augeas_parser"

describe CFA::VendorLoader do
  subject(:loader) do
    CFA::VendorLoader.new(
      parser: parser, file_handler: File, file_path: file_path, vendor_prefix: vendor_prefix, custom_prefix: custom_prefix
    )
  end
  let(:parser) { CFA::AugeasParser.new(lense) }
  let(:vendor_prefix) { File.join(DATA_PATH, "usr", "etc") }
  let(:custom_prefix) { File.join(DATA_PATH, "etc") }

  describe "#load" do
    before do
      allow(loader).to receive(:load_file).and_call_original
    end

    context "when the .conf file in /etc exists" do
      let(:lense) { "dnsmasq.lns" }
      let(:file_path) { File.join(custom_prefix, "dnsmasq.conf") }

      it "does not read the vendor files" do
        expect(loader).to_not receive(:load_file)
          .with(/usr\/etc/)
        loader.load
      end

      it "reads the custom .conf file" do
        expect(loader).to receive(:load_file)
          .with(File.join(custom_prefix, "dnsmasq.conf"))
        loader.load
      end

      it "reads the files under the .d directory" do
        expect(loader).to receive(:load_file)
          .with(File.join(custom_prefix, "dnsmasq.d", "50-yast.conf"))
        loader.load
      end
    end

    context "when the .conf file in /etc does not exists" do
      let(:lense) { "sysctl.lns" }
      let(:file_path) { File.join(DATA_PATH, "etc", "sysctl.conf") }

      before do
        allow(loader).to receive(:load_file).and_call_original
      end

      it "reads the vendor files" do
        expect(loader).to receive(:load_file)
          .with(File.join(vendor_prefix, "sysctl.conf"))
        loader.load
      end

      it "reads the files under the .d directory" do
        expect(loader).to receive(:load_file)
          .with(File.join(custom_prefix, "sysctl.d", "50-yast.conf"))
        loader.load
      end
    end
  end
end
