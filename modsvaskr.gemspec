Gem::Specification.new do |spec|
  spec.name          = 'modsvaskr'
  spec.version       = '0.0.1'
  spec.authors       = ['Muriel Salvan']
  spec.email         = ['muriel@x-aeon.com']
  spec.license       = 'BSD-3-Clause'

  spec.summary       = 'Stronghold for mods acting like companions: The Modsvaskr'
  spec.homepage      = 'http://x-aeon.com'

  spec.metadata['homepage_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.bindir = 'bin'
  spec.executables << 'modsvaskr'

  spec.add_dependency 'curses_menu', '~> 0.0'
  spec.add_dependency 'nokogiri', '~> 1.10'
end
