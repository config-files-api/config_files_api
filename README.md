Config Files Api Gem
=====================
[![Code Climate](https://codeclimate.com/github/config-files-api/config_files_api/badges/gpa.svg)](https://codeclimate.com/github/config-files-api/config_files_api)
[![Coverage Status](https://coveralls.io/repos/config-files-api/config_files_api/badge.svg?branch=master&service=github)](https://coveralls.io/github/config-files-api/config_files_api?branch=master)
Idea of gem is to have user friendly component based way to access and modify
configuration files. There is basically three layers.

The first one is layer that provides content of file and store it. It can be
replaced as needed, so it is easy to work on chroot environment, on test data
or on remote machine.

The second layer is parser, that understand configuration file structure.
There is also more possible variants like augeas based, XML parsed by standard
ruby library or CVS via cvs specialized library.

The third layer is model of file that allows more highlevel actions and its main
purpose is to ensure consistency of file and providing high level API for
file manipulation. The models live in their own gems as plugin built on top of
this gem.
