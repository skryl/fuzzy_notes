class FuzzyNotes::Notes
  include FuzzyNotes::Logger

module Defaults
  LOG_LEVEL = 1
  EDITOR='vim'
  NOTE_PATHS=[ "#{ENV['HOME']}/notes" ]
  VALID_EXTENSIONS=%w( txt enc )
  KEYWORDS = []

  def self.const_missing(*args); end
end

  OPTS = [:log_level, :editor, :note_paths, :valid_extensions, :keywords].freeze

  attr_reader :matching_notes, :all_notes

  def initialize(params = {})
    parse_init_params(params)
    FuzzyNotes::Log.init_log(@log_level)
    log.debug "init attributes: \n#{inspect_instance_vars}"

    unless note_paths_valid?
      log.error "no valid note paths found, exiting"
      exit
    end

    finder = FuzzyNotes::FuzzyFinder.new(@note_paths, 
                                        { :keywords => @keywords, 
                                          :extensions => @extensions, 
                                          :full_text_search => params[:full_text_search] })
    @all_notes, @matching_notes = finder.all_files, finder.matching_files
  end

  # initialize params or use defaults
  #
  def parse_init_params(params)
    OPTS.each do |param|
      klass = self.class
      klass.send(:attr_reader, param)
      default_const = param.to_s.upcase
      instance_variable_set("@#{param}", params[param] || Defaults.const_get(default_const) )
    end
  end
  private :parse_init_params

  # dump all matching notes to stdout
  #
  def cat
    matching_notes.each do |note_path|
      contents = \
        if encrypted?(note_path)
          puts "decrypting #{note_path}"
          FuzzyNotes::Cipher.new.decrypt(note_path)
        else
          File.read(note_path)
        end

      puts "=== #{note_path} ===\n\n"
      puts "#{contents}\n"
    end
  end

  # edit all matching notes in EDITOR
  #
  def edit
    exec("#{editor} #{bashify_paths(matching_notes)}") unless matching_notes.empty?
  end

  # encrypt matching notes 
  #
  def encrypt
    FuzzyNotes::Cipher.new.encrypt(matching_notes, :replace => true)
  end

  # decrypt matching notes
  #
  def decrypt
    FuzzyNotes::Cipher.new.decrypt(matching_notes, :replace => true)
  end

  # view WC info for all/matching notes
  #
  def info
    paths = bashify_paths(matching_notes.empty? ? all_notes : matching_notes)
    puts `wc $(find #{paths} -type f)` 
  end

private

  def note_paths_valid?
    @note_paths.any? do |p| 
      File.exists?(p) || log.info("Warning: note path '#{p}' not found")
    end
  end

  # bash style, space seperated fashion
  #
  def bashify_paths(paths)
    paths.map {|n| "\"#{n}\""}.join(' ')
  end

  def inspect_instance_vars
    instance_variables.inject("") { |s, ivar| s << "  #{ivar} => #{eval(ivar).inspect}\n" }
  end

  def encrypted?(path)
    File.extname(path)[1..-1] == FuzzyNotes::Cipher::CIPHERTEXT_EXT
  end


end
