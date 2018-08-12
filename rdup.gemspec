# encoding: utf-8

require_relative 'lib/rdup/version'

Gem::Specification.new do |s|
  s.name        = 'rdup'
  s.version     = RDup::VERSION
  s.date        = '2015-12-05'

  s.summary     = 'Find and remove duplicate files in multiple directories.'
  s.description = <<EOF
This program finds duplicate files in multiple directories and
interactively remove any of them as you wish. It is similar to fdupes,
but much faster. Written in pure Ruby. No external dependencies.
EOF

  s.authors     = ['physacco']
  s.email       = ['physacco@gmail.com']
  s.homepage    = 'https://github.com/physacco/rdup'
  s.license     = 'MIT'

  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*'] +
                  ['README.md', 'LICENSE', 'rdup.gemspec']
  s.executables = ['rdup']

  s.platform    = Gem::Platform::RUBY
  s.required_ruby_version = '>= 2.0.0'
end
