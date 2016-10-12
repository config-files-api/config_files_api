# use with `time ruby <path>` to test changes in library
# goal of this tests are to measure time, for correctness is used
# tests in spec directory

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "cfa/augeas_parser"

def load_data(path)
  File.read(File.expand_path("../data/#{path}", __FILE__))
end

parser = CFA::AugeasParser.new("hosts.lns")
parser.parse(load_data("hosts"))
