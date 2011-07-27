spec = Gem::Specification.new do |s|
  s.name = 'fuzzy_notes'
  s.version = '0.0.9'

  s.summary = "A cli note manager"
  s.description = %{A note manager with fuzzy path search, full text search, evernote sync, and encryption capabilities}
  s.files = Dir['lib/**/*.rb'] + ['bin/fnote'] + ["README", "TODO"]
  s.require_path = 'lib'
  s.bindir = 'bin'
  s.executables << 'fnote'
  s.author = "Alex Skryl"
  s.email = "rut216@gmail.com"
  s.homepage = "http://github.com/skryl"

  s.add_dependency(%q<buffered_logger>, [">= 0.1.2"])
  s.add_dependency(%q<gibberish>, [">= 0"])
  s.add_dependency(%q<evernote>, [">= 0"])
  s.add_dependency(%q<sanitize>, [">= 0"])
end
