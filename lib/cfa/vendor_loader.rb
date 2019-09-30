# frozen_string_literal: true

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

require "cfa/loader"

module CFA
  # Loader to read and combine information from different files
  #
  # Given an +/etc/example.conf+, this class loads information from different
  # places. If +/etc/example.conf+ exists, the information is read from:
  #
  # * +/etc/example.conf+
  # * +/etc/example.d/*+
  #
  # If it does not exist, it will use:
  #
  # * +/usr/etc/example.conf+
  # * +/usr/etc/example.d/*+
  # * +/etc/example.d/*+
  class VendorLoader < Loader
    VENDOR_PREFIX = "/usr/etc"
    CUSTOM_PREFIX = "/etc"

    attr_reader :vendor_prefix
    attr_reader :custom_prefix

    def initialize(
      parser:, file_handler:, file_path:, vendor_prefix: nil, custom_prefix: nil
    )
      super(parser: parser, file_handler: file_handler, file_path: file_path)
      @vendor_prefix = vendor_prefix || VENDOR_PREFIX
      @custom_prefix = custom_prefix || CUSTOM_PREFIX
    end

    # Returns merged file contents.
    #
    # @return [Object] File content (usually {AugeasTree}).
    def load
      contents = paths.map { |n| load_file(n) }
      contents.reduce(parser.empty) do |all_content, file|
        all_content.merge(file)
      end
    end

    # @return [Array<String>]
    def paths
      globs =
        if File.exist?(file_path)
          [file_path, override_paths(file_path)]
        else
          rel_file_path = file_path.sub(/\A#{custom_prefix}/, "")
          vendor_path = File.join(vendor_prefix, rel_file_path)
          [vendor_path, override_paths(vendor_path), override_paths(file_path)]
        end
      Dir.glob(globs)
    end

    # @param path [String]
    # @return [Array<String>]
    def override_paths(path)
      ext = File.extname(path)
      File.join(path.sub(/#{ext}$/, ".d"), "*")
    end
  end
end
