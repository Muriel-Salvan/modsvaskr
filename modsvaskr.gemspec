require File.expand_path("#{__dir__}/lib/modsvaskr/version")
require 'date'

Gem::Specification.new do |spec|
  spec.name = 'modsvaskr'
  spec.version = Modsvaskr::VERSION
  spec.authors = ['Muriel Salvan']
  spec.email = ['muriel@x-aeon.com']
  spec.license = 'BSD-3-Clause'
  spec.summary = 'Stronghold for mods acting like companions: The Modsvaskr'
  spec.description = 'Command-line UI handling a full Mods\' ecosystem for Bethesda\'s games.'
  spec.homepage = 'https://github.com/Muriel-Salvan/modsvaskr'
  spec.required_ruby_version = '>= 3.1'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['{bin,lib,xedit_scripts}/**/*']
  Dir['bin/**/*'].each do |exec_name|
    spec.executables << File.basename(exec_name)
  end

  spec.add_dependency 'curses_menu', '~> 0.0'
  spec.add_dependency 'elder_scrolls_plugin', '~> 0.0'
  spec.add_dependency 'nokogiri', '~> 1.13'

  # Development dependencies (tests, build)
  # Test framework
  spec.add_development_dependency 'rspec', '~> 3.12'
  # Mock HTTP calls
  spec.add_development_dependency 'webmock', '~> 3.18'
  # Automatic semantic releasing
  spec.add_development_dependency 'sem_ver_components', '~> 0.3'
  # Lint checker
  spec.add_development_dependency 'rubocop', '~> 1.41'
  # Lint checker for rspec
  spec.add_development_dependency 'rubocop-rspec', '~> 2.16'
end
