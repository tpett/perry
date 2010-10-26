# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rpc-mapper}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Travis Petticrew"]
  s.date = %q{2010-10-26}
  s.email = %q{bobo@petticrew.net}
  s.extra_rdoc_files = ["README.rdoc"]
  s.files = ["README.rdoc", "Rakefile", "lib/rpc_mapper", "lib/rpc_mapper/adapters", "lib/rpc_mapper/adapters/abstract_adapter.rb", "lib/rpc_mapper/adapters/bertrpc_adapter.rb", "lib/rpc_mapper/adapters/restful_http_adapter.rb", "lib/rpc_mapper/adapters.rb", "lib/rpc_mapper/associations", "lib/rpc_mapper/associations/common.rb", "lib/rpc_mapper/associations/contains.rb", "lib/rpc_mapper/associations/external.rb", "lib/rpc_mapper/base.rb", "lib/rpc_mapper/cacheable", "lib/rpc_mapper/cacheable/entry.rb", "lib/rpc_mapper/cacheable/store.rb", "lib/rpc_mapper/cacheable.rb", "lib/rpc_mapper/core_ext", "lib/rpc_mapper/core_ext/kernel", "lib/rpc_mapper/core_ext/kernel/singleton_class.rb", "lib/rpc_mapper/errors.rb", "lib/rpc_mapper/logger.rb", "lib/rpc_mapper/persistence.rb", "lib/rpc_mapper/relation", "lib/rpc_mapper/relation/finder_methods.rb", "lib/rpc_mapper/relation/query_methods.rb", "lib/rpc_mapper/relation.rb", "lib/rpc_mapper/scopes", "lib/rpc_mapper/scopes/conditions.rb", "lib/rpc_mapper/scopes.rb", "lib/rpc_mapper/serialization.rb", "lib/rpc_mapper/version.rb", "lib/rpc_mapper.rb"]
  s.homepage = %q{http://github.com/tpett/rpc-mapper}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Ruby library for querying and mapping data over RPC}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<shoulda>, [">= 2.10.0"])
      s.add_development_dependency(%q<leftright>, [">= 0.0.6"])
      s.add_development_dependency(%q<fakeweb>, [">= 1.3.0"])
      s.add_development_dependency(%q<factory_girl>, [">= 0"])
      s.add_runtime_dependency(%q<activesupport>, [">= 2.3.0"])
      s.add_runtime_dependency(%q<bertrpc>, [">= 1.3.0"])
    else
      s.add_dependency(%q<shoulda>, [">= 2.10.0"])
      s.add_dependency(%q<leftright>, [">= 0.0.6"])
      s.add_dependency(%q<fakeweb>, [">= 1.3.0"])
      s.add_dependency(%q<factory_girl>, [">= 0"])
      s.add_dependency(%q<activesupport>, [">= 2.3.0"])
      s.add_dependency(%q<bertrpc>, [">= 1.3.0"])
    end
  else
    s.add_dependency(%q<shoulda>, [">= 2.10.0"])
    s.add_dependency(%q<leftright>, [">= 0.0.6"])
    s.add_dependency(%q<fakeweb>, [">= 1.3.0"])
    s.add_dependency(%q<factory_girl>, [">= 0"])
    s.add_dependency(%q<activesupport>, [">= 2.3.0"])
    s.add_dependency(%q<bertrpc>, [">= 1.3.0"])
  end
end
