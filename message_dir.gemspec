# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "message_dir/version"

Gem::Specification.new do |s|
  s.name        = "message_dir"
  s.version     = Message::VERSION
  s.authors     = ["Hartog C. de Mik"]
  s.email       = ["hartog.de.mik@gmail.com"]
  s.homepage    = "https://github.com/coffeeaddict/message"
  s.summary     = %q{Maildir like messages}
  s.description = %q{Handle slow network messages with care}

  s.rubyforge_project = "message_dir"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency(%q<simple_uuid>, ['~> 0.2'])
end
