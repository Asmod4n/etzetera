# run with ruby examples/simple.rb
# i belive to have implemented most API calls, they are all in etzetera/client.rb
require 'bundler/setup'
require 'etzetera'

Etzetera::Client.supervise_as :test_client

Celluloid::Actor[:test_client].dir '/'
