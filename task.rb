require 'bundler/setup'
require 'etzetera/version'
require 'digest/sha2'

gem_name = "etzetera-#{Etzetera::VERSION}.gem"
checksum = Digest::SHA2.new.hexdigest(File.read(gem_name))
checksum_path = "checksum/#{gem_name}.sha2"
File.open(checksum_path, 'w' ) {|f| f.write(checksum) }
