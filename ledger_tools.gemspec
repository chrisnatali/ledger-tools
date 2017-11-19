# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  #TODO add detail (see RubyMoney for example)
  spec.name          = "ledger_tools"
  spec.version       = "0.1.1"
  spec.summary		   = %q{tools for ledger}
  spec.authors			 = ["Chris Natali"]
  spec.files         = Dir['README.md', '{bin,lib,spec}/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = [".", "lib"]

  spec.add_dependency "money"
  spec.add_dependency "activesupport"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-doc"
  spec.add_development_dependency "pry-byebug"
end
