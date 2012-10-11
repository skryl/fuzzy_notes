lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fuzzy_notes/version'

spec = Gem::Specification.new do |gem|
  gem.name          = "fuzzy_notes"
  gem.version       = FuzzyNotes::VERSION
  gem.authors       = ["Alex Skryl"]
  gem.email         = ["rut216@gmail.com"]
  gem.summary       = %q{A CLI note management tool}
  gem.description   = %q{A CLI note manager featuring fuzzy path search, full text search, evernote sync, and encryption capabilities}
  gem.homepage      = "https://github.com/skryl/fuzzy_notes"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency(%q<buffered_logger>, [">= 0.1.2"])
  gem.add_dependency(%q<gibberish>, [">= 0"])
  gem.add_dependency(%q<evernote>, [">= 0"])
  gem.add_dependency(%q<sanitize>, [">= 0"])
end
