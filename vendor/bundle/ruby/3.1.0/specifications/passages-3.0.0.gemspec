# -*- encoding: utf-8 -*-
# stub: passages 3.0.0 ruby lib app

Gem::Specification.new do |s|
  s.name = "passages".freeze
  s.version = "3.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze, "app".freeze]
  s.authors = ["Jake Yesbeck".freeze]
  s.date = "2020-10-13"
  s.description = "Rails Engine to make internal routes searchable and\n                      discoverable for more than just the name of the route.\n                      All aspects of a route are searchable from the HTTP\n                      verb to the paramters a route supports.".freeze
  s.email = "yesbeckjs@gmail.com".freeze
  s.homepage = "https://github.com/yez/passages".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.2.2".freeze)
  s.rubygems_version = "3.3.26".freeze
  s.summary = "Display and search capabilities for Ruby on Rails routes".freeze

  s.installed_by_version = "3.3.26" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<rails>.freeze, ["~> 6.0"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.2"])
    s.add_development_dependency(%q<rubocop>.freeze, ["= 0.49.0"])
  else
    s.add_dependency(%q<rails>.freeze, ["~> 6.0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.2"])
    s.add_dependency(%q<rubocop>.freeze, ["= 0.49.0"])
  end
end
