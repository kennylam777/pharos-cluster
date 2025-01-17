
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "pharos/version"

files = Dir['README.md', 'LICENSE', 'licenses/*', 'bin/*', 'lib/**/*', 'addons/**/*']
require_paths = ['lib']
if ENV['PHAROS_NON_OSS'] == 'true'
  files += Dir['non-oss/**/*']
  require_paths << 'non-oss'
end

Gem::Specification.new do |spec|
  spec.name          = "pharos-cluster"
  spec.version       = Pharos::VERSION.sub('-', '.')
  spec.authors       = ["Kontena, Inc."]
  spec.email         = ["info@kontena.io"]

  spec.summary       = "Kontena Pharos cluster manager"
  spec.homepage      = "https://github.com/kontena/pharos-cluster"
  spec.license       = ENV['PHAROS_NON_OSS'] == 'true' ? "Nonstandard" : "Apache-2.0"

  spec.files         = files
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = require_paths
  spec.required_ruby_version = '~> 2.5'

  spec.add_runtime_dependency "clamp", "1.2.1"
  spec.add_runtime_dependency "pastel", "~> 0.7"
  spec.add_runtime_dependency "net-ssh", "~> 5.2.0"
  spec.add_runtime_dependency "ed25519", "~> 1.2"
  spec.add_runtime_dependency "bcrypt", "~> 3.1"
  spec.add_runtime_dependency "bcrypt_pbkdf", "~> 1.0"
  spec.add_runtime_dependency "dry-types", "0.13.2"
  spec.add_runtime_dependency "dry-validation", "0.12.1"
  spec.add_runtime_dependency "dry-struct", "0.5.0"
  spec.add_runtime_dependency "dry-logic", "0.4.2"
  spec.add_runtime_dependency "fugit", "~> 1.1.2"
  spec.add_runtime_dependency "rouge", "~> 3.1"
  spec.add_runtime_dependency "tty-prompt", "~> 0.16"
  spec.add_runtime_dependency "k8s-client", "~> 0.10.1"
  spec.add_runtime_dependency "yaml-safe_load_stream", "~> 0.1"
  spec.add_runtime_dependency "excon", "~> 0.62.0"

  spec.add_development_dependency "bundler", ">= 1.17.2", "<= 3.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "fakefs", "~> 0.13"
  spec.add_development_dependency "rubocop", "0.66.0"
  spec.add_development_dependency "pry-byebug", "~> 3.6"
end
