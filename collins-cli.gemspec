# encoding: utf-8

Gem::Specification.new do |s|
  s.name          = 'collins-cli'
  s.version       = '0.2.11'
  s.authors       = ['Gabe Conradi']
  s.email         = ['gabe.conradi@gmail.com','gummybearx@gmail.com']
  s.homepage      = 'http://github.com/byxorna/collins-cli'
  s.summary       = %q{CLI utilities to interact with the Collins API}
  s.description   = %q{CLI utilities to interact with the Collins API}
  s.license       = 'Apache License 2.0'

  s.files         = Dir['lib/**/*.rb', 'bin/*', 'README.md']
  s.test_files    = Dir['spec/**/*.rb']
  s.require_paths = %w(lib)
  s.bindir        = 'bin'
  s.executables   = Dir.glob('bin/*').map{|x| File.basename x}

  s.add_dependency "colorize", '~> 0.7.3'
  s.add_dependency "collins_auth", '~> 0.1.2'
  s.add_dependency "collins_client", '~> 0.2.18'
  s.add_development_dependency "rake", '~> 10.4.0'
  s.add_development_dependency "rspec", '~> 3.1.0'

  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.9.2'
end
