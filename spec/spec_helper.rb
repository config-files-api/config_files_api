$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

def load_data(path)
  File.read(File.expand_path("../data/#{path}", __FILE__))
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
  # do not cover specs
  SimpleCov.add_filter "_spec.rb"

  # for coverage we need to load all ruby files
  src_location = File.expand_path("../../", __FILE__)
  SimpleCov.track_files("#{src_location}/lib/**/*.rb")

  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    )
  end
end
