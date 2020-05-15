require_relative "lib/net/telnet/rfc2217/version"

Gem::Specification.new do |s|
  s.name = 'net-telnet-rfc2217'
  s.version = Net::Telnet::RFC2217::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Cody Cutrer"]
  s.email = "cody@cutrer.com'"
  s.homepage = "https://github.com/ccutrer/net-telnet-2217"
  s.summary = "Library for getting an IO-like object for a remote serial port"
  s.license = "MIT"

  s.files = Dir["{lib}/**/*"]

  s.add_dependency 'net-telnet', "~> 0.2.0"

  s.add_development_dependency 'byebug', "~> 9.0"
  s.add_development_dependency 'rake', "~> 13.0"
end
