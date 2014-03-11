# run with ruby examples/ssl.rb
require 'bundler/setup'
require 'etzetera'

ssl_context      = OpenSSL::SSL::SSLContext.new
ssl_context.cert = OpenSSL::X509::Certificate.new(File.read('path_to_your.client.cert.pem'))
ssl_context.key  = OpenSSL::PKey::RSA.new(File.read('path_to_your.client.key'))
ssl_context.ca_file = File.read('path_to_your.root.ca.pem')

Etzetera::Client.supervise_as :test_client, ['https://etcd.host:port'], :ssl_context => ssl_context

Celluloid::Actor[:test_client].dir '/'
