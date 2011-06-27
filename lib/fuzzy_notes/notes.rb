class FuzzyNotes::Notes
  include FuzzyNotes::Logger

INIT_PARAMS = :log_level, :editor, :note_paths, :valid_extensions, :keywords

# param defaults
#
LOG_LEVEL = 1
EDITOR='vim'
NOTE_PATHS=[ "#{ENV['HOME']}/notes" ]
VALID_EXTENSIONS=%w( txt enc )
KEYWORDS = []

attr_reader :matching_notes, :all_notes

def initialize(params = {})
  parse_init_params(params)
  FuzzyNotes::Log.init_log(@log_level)
  log.debug "[debug] init attributes: \n#{attributes}"

  unless note_paths_valid?
    log.error "ERROR: no valid note paths found, exiting"
    exit
  end

  @all_notes, @matching_notes = \
    FuzzyNotes::FuzzyFinder.find(@note_paths, { :keywords => @keywords, 
                                                :extensions => @extensions,
                                                :full_text_search => params[:full_text_search] })
end

# dump all matching notes to stdout
#
def cat
  matching_notes.each do |n|
    puts "=== #{n} ===\n\n"
    puts "#{File.read(n)}\n"
  end
end


# edit all matching notes in EDITOR
#
def edit
  exec("#{editor} #{bashify_paths(matching_notes)}") if !matching_notes.empty?
end


# encrypt matching notes 
#
def encrypt
  FuzzyNotes::Cipher.apply_cipher(matching_notes)
end


# decrypt matching notes
#
def decrypt
  FuzzyNotes::Cipher.apply_cipher(matching_notes, true)
end


# view WC info for all/matching notes
def info
  paths = bashify_paths(matching_notes.empty? ? all_notes : matching_notes)
  puts `wc $(find #{paths} -type f)` 
end


private


# initialize params or use defaults
#
def parse_init_params(params)
  INIT_PARAMS.each do |param|
    klass = self.class
    klass.send(:attr_reader, param)
    const_name = param.to_s.upcase
    instance_variable_set("@#{param}", params[param] || 
                                       (klass.const_defined?(const_name) ? klass.const_get(const_name) : nil) )
  end
end


def note_paths_valid?
  @note_paths.any? do |p| 
    File.exists?(p) || log.info("Warning: note path '#{p}' not found")
  end
end


# lists matching note paths in bash style, space seperated fashion
def bashify_paths(paths)
  paths.map {|n| "\"#{n}\""}.join(' ')
end


def attributes
  instance_variables.inject("") { |s, ivar| s << "  #{ivar} => #{eval(ivar).inspect}\n" }
end


end
