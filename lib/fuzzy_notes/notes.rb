require 'gibberish'

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

attr_reader :notes, :all_notes

def initialize(params = {})
  parse_init_params(params)

  unless @note_paths.any? { |p| File.exists?(p) }
    log.error "ERROR: no valid note paths found"
    exit
  end

  @all_notes, @notes = \
    FuzzyNotes::FuzzyFinder.find(@note_paths, { :keywords => @keywords, 
                                                :extensions => @extensions,
                                                :full_text_search => params[:full_text_search] })
end

def parse_init_params(params)
  INIT_PARAMS.each do |param|
    klass = self.class
    klass.send(:attr_reader, param)
    const_name = param.to_s.upcase
    instance_variable_set("@#{param}", params[param] || 
                                       (klass.const_defined?(const_name) ? klass.const_get(const_name) : nil) )
  end
  FuzzyNotes::Log.init_log(@log_level)

  ivar_values = instance_variables.inject("") { |s, ivar| s << "  #{ivar} => #{eval(ivar).inspect}\n" }
  log.debug "[debug] init attributes: \n#{ivar_values}"
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
  exec("#{editor} #{bashify_paths(notes)}") if !notes.empty?
end


def encrypt
  apply_cipher
end


def decrypt
  apply_cipher(true)
end


# view WC info for all/matching notes
def info
  paths = bashify_paths(notes.empty? ? all_notes : notes)
  puts `wc $(find #{paths} -type f)` 
end


private


def apply_cipher(decrypt = false)
  extension, action = decrypt ? ['.txt', 'dec'] : ['.enc', 'enc']
  password = get_password
  cipher = Gibberish::AES.new(password)
  notes.each do |note|
    log.info "#{action} '#{note}'"
    pathname = File.dirname(note)
    filename = File.basename(note, '.*')
    begin
      ciphertext = cipher.send(action, File.read(note))
      log.debug "[debug] writing encrypted content to: #{pathname}/#{filename}#{extension}"
      File.open("#{pathname}/#{filename}#{extension}", 'w') { |f| f << ciphertext }
      log.debug "[debug] deleting unencrypted file: #{note}"
      File.delete(note)
    rescue OpenSSL::Cipher::CipherError => e
      log.error "ERROR: #{e}"
    end
  end
end


def get_password
  printf 'Enter password (will not be shown):'
  `stty -echo`; password = STDIN.gets.strip;`stty echo`; puts
  log.debug "[debug] entered password: #{password.inspect}"
  password
end


# lists matching note paths in bash style, space seperated fashion
def bashify_paths(paths)
  paths.map {|n| "\"#{n}\""}.join(' ')
end

end
