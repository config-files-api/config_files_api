Gem::Specification.new do |s|
  s.name        = "config_files_api"
  s.version     = "0.1.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Josef Reidinger"]
  s.email       = ["jreidinger@suse.cz"]
  s.homepage    = "http://github.com/config-files-api/config_files_api"
  s.summary     = "Easy way to create model on top of configuration file"
  s.description = "Library provides support for separing parser and file" \
    " loader from rest of logic for configuration files. It provides support" \
    " for parsing using augeas lenses and also for working with files" \
    " directly in memory."

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "ruby-augeas"

  s.files        = Dir["{lib}/**/*.rb"]
  s.require_path = "lib"
end
