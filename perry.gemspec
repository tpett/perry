# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{perry}
  s.version = "0.7.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Travis Petticrew}]
  s.date = %q{2011-11-11}
  s.email = %q{bobo@petticrew.net}
  s.extra_rdoc_files = [%q{README.rdoc}]
  s.files = [%q{README.rdoc}, %q{Rakefile}, %q{lib/perry}, %q{lib/perry/adapters}, %q{lib/perry/adapters/abstract_adapter.rb}, %q{lib/perry/adapters/bertrpc_adapter.rb}, %q{lib/perry/adapters/restful_http_adapter.rb}, %q{lib/perry/adapters.rb}, %q{lib/perry/association.rb}, %q{lib/perry/associations}, %q{lib/perry/associations/common.rb}, %q{lib/perry/associations/contains.rb}, %q{lib/perry/associations/external.rb}, %q{lib/perry/base.rb}, %q{lib/perry/caching.rb}, %q{lib/perry/core_ext}, %q{lib/perry/core_ext/kernel}, %q{lib/perry/core_ext/kernel/singleton_class.rb}, %q{lib/perry/errors.rb}, %q{lib/perry/logger.rb}, %q{lib/perry/middlewares}, %q{lib/perry/middlewares/cache_records}, %q{lib/perry/middlewares/cache_records/entry.rb}, %q{lib/perry/middlewares/cache_records/scopes.rb}, %q{lib/perry/middlewares/cache_records/store.rb}, %q{lib/perry/middlewares/cache_records.rb}, %q{lib/perry/middlewares/model_bridge.rb}, %q{lib/perry/middlewares.rb}, %q{lib/perry/persistence}, %q{lib/perry/persistence/response.rb}, %q{lib/perry/persistence.rb}, %q{lib/perry/processors}, %q{lib/perry/processors/preload_associations.rb}, %q{lib/perry/processors.rb}, %q{lib/perry/relation}, %q{lib/perry/relation/finder_methods.rb}, %q{lib/perry/relation/modifiers.rb}, %q{lib/perry/relation/query_methods.rb}, %q{lib/perry/relation.rb}, %q{lib/perry/scopes}, %q{lib/perry/scopes/conditions.rb}, %q{lib/perry/scopes.rb}, %q{lib/perry/serialization.rb}, %q{lib/perry/support}, %q{lib/perry/support/class_attributes.rb}, %q{lib/perry/version.rb}, %q{lib/perry.rb}]
  s.homepage = %q{http://github.com/tpett/perry}
  s.rdoc_options = [%q{--main}, %q{README.rdoc}]
  s.require_paths = [%q{lib}]
  s.rubygems_version = %q{1.8.9}
  s.summary = %q{Ruby library for querying and mapping data through generic interfaces}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<shoulda>, [">= 2.10.0"])
      s.add_development_dependency(%q<leftright>, [">= 0.0.6"])
      s.add_development_dependency(%q<fakeweb>, [">= 1.3.0"])
      s.add_development_dependency(%q<factory_girl>, [">= 0"])
      s.add_runtime_dependency(%q<activesupport>, [">= 2.3.0"])
      s.add_runtime_dependency(%q<bertrpc>, [">= 1.3.0"])
      s.add_runtime_dependency(%q<json>, [">= 1.4.6"])
    else
      s.add_dependency(%q<shoulda>, [">= 2.10.0"])
      s.add_dependency(%q<leftright>, [">= 0.0.6"])
      s.add_dependency(%q<fakeweb>, [">= 1.3.0"])
      s.add_dependency(%q<factory_girl>, [">= 0"])
      s.add_dependency(%q<activesupport>, [">= 2.3.0"])
      s.add_dependency(%q<bertrpc>, [">= 1.3.0"])
      s.add_dependency(%q<json>, [">= 1.4.6"])
    end
  else
    s.add_dependency(%q<shoulda>, [">= 2.10.0"])
    s.add_dependency(%q<leftright>, [">= 0.0.6"])
    s.add_dependency(%q<fakeweb>, [">= 1.3.0"])
    s.add_dependency(%q<factory_girl>, [">= 0"])
    s.add_dependency(%q<activesupport>, [">= 2.3.0"])
    s.add_dependency(%q<bertrpc>, [">= 1.3.0"])
    s.add_dependency(%q<json>, [">= 1.4.6"])
  end
end
