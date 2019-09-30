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

module CFA
  # This class is responsible for loading a file using a parser.
  #
  # {Loader} can be specialized to support more complex scenarios, like reading
  # configuration information from different sources. See {VendorLoader} for an
  # example.
  #
  # @example Loading and merging configuration files
  #   loader = Loader.new(
  #     parser: AugeasParser.new("sysconfig.lns"),
  #     file_handler: File,
  #     file_path: "/etc/zypp/zypp.conf"
  #   ) #=> #<CFA::Loader:...>
  #   content = loader.load #=> #<CFA::AugeasTree:...>
  class Loader
    def initialize(parser:, file_handler:, file_path:)
      @parser = parser
      @file_handler = file_handler
      @file_path = file_path
    end

    def load
      load_file(file_path)
    end

  private

    attr_reader :parser, :file_handler, :file_path

    def load_file(file_path)
      @parser.file_name = file_path if @parser.respond_to?(:file_name=)
      @parser.parse(@file_handler.read(file_path))
    end
  end
end
