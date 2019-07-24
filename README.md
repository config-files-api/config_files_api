CFA - Config Files Api Gem
=====================
[![Code Climate](https://codeclimate.com/github/config-files-api/config_files_api/badges/gpa.svg)](https://codeclimate.com/github/config-files-api/config_files_api)
[![Coverage Status](https://coveralls.io/repos/config-files-api/config_files_api/badge.svg?branch=master&service=github)](https://coveralls.io/github/config-files-api/config_files_api?branch=master)
Ruby gem providing a modular and developer friendly way to access and modify
configuration files in a  system. It's structured in three layers.

The first layer provides access to the file and its content. By default it
accesses the local system, but it can be replaced by alternatives to work
on a chroot environment, on test data, on a remote machine or any other
scenario.

The second layer is the parser, that understands the structure
of the configuration files. There are also several possible variants like augeas
based, XML parsed by standard ruby library or CVS via cvs specialized library.

The third layer consist on a set of models representing the files to provide
more high level actions. Its main purposes are to ensure consistency of the
files and to provide high level API for manipulating the files. The models
live in their own gems as plugins built on top of this gem.

This Maintenance Branch
----------------------

This branch is specifically created for maintaining version on SLE 12 SP5.
Specifics:

- rubocop disabled
- ruby2.1 used
- gem is not pushed to rubygems.org

How to Release This Branch
--------------------------
There is tag SLE12-SP5-base which can be used to generate series of patches on top of gem used in SLE12 SP5.
Always try to separate commits with changes in lib and without changes in lib, because in IBS patch
is applied on unpacked gem which contain only lib directory and gemspec. Patches which does not apply
to gem mark as NOPATCH. So generate patches and remove one not for gem:

```
git format-patch SLE12-SP5-base..HEAD && rm *NOPATCH*.patch
```

Copy all patches to IBS repository (Devel:YaST:SLE12-SP5), adapt spec file and copy CHANGELOG to changes file.
