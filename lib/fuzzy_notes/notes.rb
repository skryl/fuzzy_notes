require 'tempfile'

class FuzzyNotes::Notes
  include FuzzyNotes::Logger

module Defaults
  LOG_LEVEL   = :info
  EDITOR      = 'vim'
  KEYWORDS    = []
  NOTE_PATHS  = [ "#{ENV['HOME']}/notes" ]
  VALID_EXTENSIONS = [ 'txt', 
                       FuzzyNotes::Cipher::CIPHERTEXT_EXT, 
                       FuzzyNotes::Cipher::PLAINTEXT_EXT, 
                       FuzzyNotes::EvernoteSync::NOTE_EXT ]

  def self.const_missing(*args); end
end

  VALID_PARAMS = [:log_level, :no_color, :editor, :note_paths, :valid_extensions, :keywords, :evernote_params].freeze

  attr_reader :matching_notes, :all_notes

  def initialize(params = {})
    parse_init_params(params)
    FuzzyNotes::Log.init_log(@log_level, !@no_color)
    log.debug "init params: \n#{inspect_instance_vars}"
    exit unless note_paths_valid?

    finder = FuzzyNotes::FuzzyFinder.new(@note_paths, 
                                        { :keywords => @keywords, 
                                          :extensions => @extensions, 
                                          :full_text_search => params[:full_text_search] })
    @all_notes, @matching_notes = finder.files_matching_extension, finder.files_matching_all
  end

  # dump all matching notes to stdout
  #
  def cat
    unless encrypted_notes.empty?
      print_notes(:encrypted => true)
      decrypted_notes = FuzzyNotes::Cipher.new.decrypt_files(encrypted_notes)
    end

    matching_notes.each do |note_path|
      contents = \
        if FuzzyNotes::Cipher.encrypted?(note_path)
          decrypted_notes.shift
        elsif FuzzyNotes::EvernoteSync.evernote?(note_path)
          FuzzyNotes::EvernoteSync.sanitize_evernote(note_path)
        else
          File.read(note_path)
        end

      if contents
        log.info "=== #{note_path} ===\n\n"
        puts "#{contents}\n"
      end
    end
  end

  # edit all matching notes in EDITOR
  #
  def edit
    notes_to_edit = \
      unless encrypted_notes.empty?
        print_notes(:encrypted => true)
        decrypted_tempfiles = FuzzyNotes::Cipher.new.decrypt_to_tempfiles(encrypted_notes)
        notes_tempfiles = decrypted_tempfiles.zip(encrypted_notes)
        successfully_decrypted_files = decrypted_tempfiles.compact 
        plaintext_notes + successfully_decrypted_files
      else plaintext_notes
      end

    # edit decrypted files
    unless notes_to_edit.empty?
      system("#{editor} #{bashify_note_paths(notes_to_edit)}")
    end

    # reencrypt decrypted notes
    unless successfully_decrypted_files.empty? 
      FuzzyNotes::Cipher.new.encrypt_from_tempfiles(notes_tempfiles) 
    end
  end

  # encrypt matching notes 
  #
  def encrypt
    return if plaintext_notes.empty?
    print_notes(:plaintext => true)
    log.indent do 
      FuzzyNotes::Cipher.new.encrypt_files(plaintext_notes, :replace => true)
    end
  end

  # decrypt matching notes
  #
  def decrypt
    return if encrypted_notes.empty?
    print_notes(:encrypted => true)
    log.indent do
      FuzzyNotes::Cipher.new.decrypt_files(encrypted_notes, :replace => true)
    end
  end

  # view WC info for all/matching notes
  #
  def info
    paths = bashify_note_paths(matching_notes(:all_if_empty => true))
    puts `wc $(find #{paths} -type f)` 
  end

  def list
    print_notes(:all_if_empty => true)
  end

  def evernote_sync
    return unless evernote_params_found?
    FuzzyNotes::EvernoteSync.new(@evernote_params).sync
  end

private

  def encrypted_notes
    @encrypted_notes ||= matching_notes.select { |note_path| FuzzyNotes::Cipher.encrypted?(note_path) }
  end

  def evernote_notes
    @evernote_notes ||= matching_notes.select { |note_path| FuzzyNotes::EvernoteSync.evernote?(note_path) }
  end

  def plaintext_notes
    @plaintext_notes ||= matching_notes.select { |note_path| !FuzzyNotes::Cipher.encrypted?(note_path) && 
                                                             !FuzzyNotes::EvernoteSync.evernote?(note_path) }
  end


  def note_paths_valid?
    valid_path_exists = @note_paths.any? do |p| 
      File.directory?(p) || log.warn("note path #{PATH_COLOR} #{p} does not exist")
    end
    unless valid_path_exists
      log.error "no valid note paths found, exiting"
      false
    else true
    end
  end

  # TODO: grab creds from user
  def evernote_params_found?
    unless @evernote_params
      log.error("required evernote configuration not found!")
      false
    else true
    end
  end

  # bash helpers
  #
  def bashify_note_paths(paths)
    paths.map {|n| "\"#{n}\""}.join(' ')
  end

  def print_notes(params = {})
    notes = []
    
    notes << encrypted_notes if params[:encrypted]
    notes << evernote_notes if params[:evernote]
    notes << plaintext_notes if params[:plaintext]
    if notes.empty?
      notes << matching_notes(:all_if_empty => true)
    end
    
    notes.flatten!
    keys = params.keys.reject { |k| k == :all_if_empty }
    log.info "#{keys.join(',')} notes:"
    log.indent { notes.each { |note| log.info "#{PATH_COLOR} #{note}" } }
  end

  def matching_notes(params = {})
    (@matching_notes.empty? && params[:all_if_empty]) ? @all_notes : @matching_notes
  end

  # initialize to params or use defaults
  #
  def parse_init_params(params)
    VALID_PARAMS.each do |param|
      klass = self.class
      klass.send(:attr_reader, param)
      default_const = param.to_s.upcase

      value = \
        if params.include?(param) 
          params[param] 
        else Defaults.const_get(default_const)
        end
     instance_variable_set("@#{param}", value) 
    end
  end

  def inspect_instance_vars
    instance_variables.inject("") { |s, ivar| s << "  #{ivar} => #{eval(ivar.to_s).inspect}\n" }
  end


end
