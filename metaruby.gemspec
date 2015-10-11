# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'metaruby/version'

Gem::Specification.new do |s|
    s.name = "metaruby"
    s.version = MetaRuby::VERSION
    s.authors = ["Sylvain Joyeux"]
    s.email = "sylvain.joyeux@m4x.org"
    s.summary = "Modelling using the Ruby language as a metamodel"
    s.description = "MetaRuby is a set of module and classes that help one use the Ruby type system as a basis for modelling."
    s.homepage = "http://rock-robotics.org"
    s.licenses = ["BSD"]

    s.require_paths = ["lib"]
    s.extensions = []
    s.extra_rdoc_files = ["README.md"]
    s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }

    s.add_runtime_dependency "utilrb", ">= 3.0.0.a"
    s.add_runtime_dependency "kramdown"
    s.add_development_dependency "flexmock", ">= 2.0.0"
    s.add_development_dependency "minitest", ">= 5.0", "~> 5.0"
    s.add_development_dependency "coveralls"
end
