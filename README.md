CFA - Config Files Api Gem
=====================
[![Code Climate](https://codeclimate.com/github/config-files-api/config_files_api/badges/gpa.svg)](https://codeclimate.com/github/config-files-api/config_files_api)
[![Coverage Status](https://coveralls.io/repos/config-files-api/config_files_api/badge.svg?branch=master&service=github)](https://coveralls.io/github/config-files-api/config_files_api?branch=master)
Ruby gem providing a modular and developer friendly way to access and modify
configuration files in a  system. It's structured in four layers.

The first layer provides access to the file and its content. By default it
accesses the local system, but it can be replaced by alternatives to work
on a chroot environment, on test data, on a remote machine or any other
scenario.

The second layer is the parser, that understands the structure
of the configuration files. There are also several possible variants like augeas
based, XML parsed by standard ruby library or CVS via cvs specialized library.

The third layer are the loaders, which are able to merge the data from different
files for cases where the configuration is spread accross several files. For
instance, think about the typical `<example>.d` directories, like `pam.d`.

The fourth layer consist on a set of models representing the configuration to
provide more high level actions. Its main purposes are to ensure consistency of
the configuration and to provide high level API for manipulating it. The models
live in their own gems as plugins built on top of this gem.
