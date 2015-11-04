$LOAD_PATH << File.expand_path("../../lib", __FILE__)

require "config_files/grub2/default"
require "config_files/memory_file"

grub_path = File.expand_path("../data/grub.cfg", __FILE__)
memory_file = ConfigFiles::MemoryFile.new(File.read(grub_path))
config = ConfigFiles::Grub2::Default.new(file_handler: memory_file)
config.load

puts "config: " + config.inspect
puts ""
puts "os prober:  #{config.os_prober.enabled?}"

config.os_prober.disable
config.enable_recovery_entry "\"kernel_do_your_job=HARD!\""

config.save

puts
puts "Testing output:"
puts memory_file.content
