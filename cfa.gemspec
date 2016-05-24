Gem::Specification.new do |s|
  s.name        = "cfa"
  s.version     = "0.3.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Josef Reidinger"]
  s.email       = ["jreidinger@suse.cz"]
  s.homepage    = "http://github.com/config-files-api/config_files_api"
  s.license     = "LGPL-3.0"
  s.summary     = "CFA (Config Files API) provides an easy way to create" \
    " models on top of configuration files"
  s.description = "Library offering separation of parsing and file access from"\
    " the rest of the logic for managing configuraton files."\
    " It has built-in support for parsing using augeas lenses and also for"\
    " working with files directly in memory."

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "ruby-augeas"

  s.files        = Dir["{lib}/**/*.rb"]
  s.require_path = "lib"
end
