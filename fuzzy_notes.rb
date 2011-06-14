require 'fuzzy_finder'
require 'rubygems'
require 'active_support/buffered_logger'

class FuzzyNotes

LOG_LEVEL = 1
EDITOR='vim'
NOTE_PATH=[ "#{ENV['HOME']}/Dropbox/notes" ]
NOTE_EXTENSIONS=%w( txt )

attr_reader :keywords, :notes, :all_notes
private :keywords, :notes, :all_notes


def initialize(keywords, opts = {})
  log.debug "notes path: #{NOTE_PATH.inspect}"
  @keywords = keywords
  @all_notes, @notes = FuzzyFinder.find(NOTE_PATH, :keywords => keywords, :extensions => NOTE_EXTENSIONS)
end


# cat all matching notes to stdout
def cat
  notes.each do |n|
    puts "=== #{n} ===\n\n"
    puts "#{File.read(n)}\n"
  end
end


# edit all matching notes in EDITOR
def edit
  exec("#{EDITOR} #{bashify_paths(notes)}") if notes
end


# view WC info for all/matching notes
def info
  paths = bashify_paths(notes.empty? ? all_notes : notes)
  puts `wc $(find #{paths} -type f)` 
end


private

def log
  @log || ActiveSupport::BufferedLogger.new(STDOUT, LOG_LEVEL)
end

# lists matching note paths in bash style, space seperated fashion
def bashify_paths(paths)
  paths.map {|n| "\"#{n}\""}.join(' ')
end

end
