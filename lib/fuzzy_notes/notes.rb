class FuzzyNotes::Notes
  include FuzzyNotes::Logger

module Defaults
  LOG_LEVEL   = 1
  EDITOR      = 'vim'
  COLOR       = true
  KEYWORDS    = []
  NOTE_PATHS  = [ "#{ENV['HOME']}/notes" ]
  VALID_EXTENSIONS = [ 'txt', 
                       FuzzyNotes::Cipher::CIPHERTEXT_EXT, 
                       FuzzyNotes::Cipher::PLAINTEXT_EXT, 
                       FuzzyNotes::EvernoteSync::NOTE_EXT ]

  def self.const_missing(*args); end
end

  OPTS = [:log_level, :color, :editor, :note_paths, :valid_extensions, :keywords, :evernote_params].freeze

  attr_reader :matching_notes, :all_notes

  def initialize(params = {})
    parse_init_params(params)
    FuzzyNotes::Log.init_log(@log_level, @color)
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
      instance_variable_set("@#{param}", params.include?(param) ? params[param] : Defaults.const_get(default_const) )
    end
  end
  private :parse_init_params

  # dump all matching notes to stdout
  #
  def cat
    matching_notes.each do |note_path|
      contents = \
        if FuzzyNotes::Cipher.encrypted?(note_path)
          log.info "decrypting note #{Colors::PATH} #{note_path}"
          FuzzyNotes::Cipher.new.decrypt(note_path)
        elsif evernote?(note_path)
          FuzzyNotes::EvernoteSync.sanitize_evernote(note_path)
        else
          File.read(note_path)
        end

      unless contents.blank?
        log.info "=== #{note_path} ===\n\n"
        puts "#{contents}\n"
      end
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
    return if matching_notes.empty?
    log.info "encrypting matching notes:"
    print_notes
    log.indent(2) { FuzzyNotes::Cipher.new.encrypt(matching_notes, :replace => true) }
  end

  # decrypt matching notes
  #
  def decrypt
    return if matching_notes.empty?
    log.info "decrypting matching notes:"
    print_notes
    log.indent(2) { FuzzyNotes::Cipher.new.decrypt(matching_notes, :replace => true) }
  end

  # view WC info for all/matching notes
  #
  def info
    paths = bashify_paths(matching_notes.empty? ? all_notes : matching_notes)
    puts `wc $(find #{paths} -type f)` 
  end

  def list
    print_notes(:all => true)
  end

  def evernote_sync
    unless @evernote_params
      log.error("no evernote configuration found!")
      return
    end

    log.info "syncing evernote directory #{Colors::PATH} #{@evernote_params[:note_path]}"
    FuzzyNotes::EvernoteSync.new(@evernote_params).sync
    log.print_blank_line
  end

private

  def note_paths_valid?
    @note_paths.any? do |p| 
      File.directory?(p) || log.warn("note path #{Colors::PATH} #{p} does not exist")
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

  def evernote?(path)
    File.extname(path)[1..-1] == FuzzyNotes::EvernoteSync::NOTE_EXT
  end

  def print_notes(params = {})
    notes = (matching_notes.empty? && params[:all]) ? all_notes : matching_notes
    log.indent(2) { notes.each { |note| log.info "#{Colors::PATH} #{note}" } }
  end

end
