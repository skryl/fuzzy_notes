require 'fuzzy_finder'
require 'rubygems'
require 'active_support/buffered_logger'
require 'gibberish'

class FuzzyNotes

LOG_LEVEL = 1
EDITOR='vim'
NOTE_PATH=[ "#{ENV['HOME']}/Dropbox/notes" ]
NOTE_EXTENSIONS=%w( txt enc )

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
    puts "#{action} '#{note}'"
    pathname = File.dirname(note)
    filename = File.basename(note, '.*')
    begin
      ciphertext = cipher.send(action, File.read(note))
      File.open("#{pathname}/#{filename}#{extension}", 'w') { |f| f << ciphertext }
      File.delete(note)
    rescue OpenSSL::Cipher::CipherError => e
      puts "  ERROR: #{e}"
    end
  end
end

def get_password
  printf 'Enter password (will not be shown):'
  `stty -echo`; password = STDIN.gets.strip;`stty echo`; puts
  password
end

# lists matching note paths in bash style, space seperated fashion
def bashify_paths(paths)
  paths.map {|n| "\"#{n}\""}.join(' ')
end

def log
  @log || ActiveSupport::BufferedLogger.new(STDOUT, LOG_LEVEL)
end

end
