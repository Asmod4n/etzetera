$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__)) unless $LOAD_PATH.include?(File.expand_path('../lib', __FILE__))
require 'etzetera/version'

Gem::Specification.new do |gem|
  gem.authors       = %w[Hendrik Beskow]
  gem.email         = %w[hendrik@beskow.de]
  gem.description   = 'A etcd Client written in Ruby'
  gem.summary       = 'etcd ruby client'
  gem.homepage      = 'https://github.com/Asmod4n/etzetera'
  gem.license       = 'Apache 2.0'

  gem.files         = [
    'lib/etzetera.rb',
    'lib/etzetera/version.rb',
    'lib/etzetera/core_ext.rb',
    'lib/etzetera/error.rb',
    'lib/etzetera/client.rb',
    'LICENSE',
    'README.md'
  ]

  gem.name          = 'etzetera'
  gem.require_paths = %w[lib]
  gem.version       = Etzetera::VERSION

  gem.add_dependency 'celluloid-io', '~> 0.15'
  gem.add_dependency 'http', '~> 0.5'
  gem.add_dependency 'multi_json', '~> 1.8'
  gem.add_development_dependency 'bundler', '~> 1.5'
end
.tap {|gem| gem.signing_key = File.expand_path(File.join('~/.keys', 'gem-private_key.pem')) if $0 =~ /gem\z/ ; gem.cert_chain = ['gem-public_cert.pem']} # pressed firmly by waxseal
