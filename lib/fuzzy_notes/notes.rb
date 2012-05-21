require 'tempfile'

module FuzzyNotes::Defaults
  LOG_LEVEL   = :info
  EDITOR      = 'vim'
  VIEWER      = 'open'
  KEYWORDS    = []
  NOTE_PATHS  = [ "#{ENV['HOME']}/notes" ]
  FULL_TEXT_SEARCH = false
  VALID_EXTENSIONS = [ FuzzyNotes::TextViewer::TXT_EXT, 
                       FuzzyNotes::Cipher::CIPHERTEXT_EXT, 
                       FuzzyNotes::Cipher::PLAINTEXT_EXT, 
                       FuzzyNotes::EvernoteSync::NOTE_EXT] + 
                       FuzzyNotes::ImageViewer::IMG_EXTS

  def self.const_missing(*args); end
end

class FuzzyNotes::Notes
  include FuzzyNotes::Logger

  VALID_PARAMS = [:log_level, :color, :editor, :viewer, :note_paths,
                  :valid_extensions, :custom_extensions, :full_text_search,
                  :keywords, :evernote_params].freeze

  attr_reader :matching_notes, :all_notes

  def initialize(params = {})
    @params = params
    parse_init_params
    
    init_logger
    init_cipher
    init_finder
    
    @all_notes = @finder.files_matching_extension 
    @matching_notes = @finder.files_matching_all
  end

  # dump all matching notes to stdout
  #
  def cat
    unless encrypted_notes.empty?
      print_notes(:encrypted => true)
      decrypted_notes = @cipher.decrypt_files(encrypted_notes)
    end

    matching_notes.each do |note_path|
      contents = \
        if FuzzyNotes::Cipher.encrypted?(note_path)
          decrypted_notes.shift
        elsif FuzzyNotes::EvernoteSync.evernote?(note_path)
          FuzzyNotes::EvernoteSync.sanitize_evernote(note_path)
        elsif FuzzyNotes::ImageViewer.image?(note_path)
          FuzzyNotes::ImageViewer.display(@viewer, note_path)
        else
          FuzzyNotes::TextViewer.read(note_path)
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
        decrypted_tempfiles = @cipher.decrypt_to_tempfiles(encrypted_notes)
        successfully_decrypted_files = decrypted_tempfiles.compact 
        plaintext_notes + successfully_decrypted_files
      else plaintext_notes
      end

    # edit decrypted files
    unless notes_to_edit.empty?
      system("#{@editor} #{bashify_note_paths(notes_to_edit)}")
    end

    # reencrypt decrypted notes
    unless encrypted_notes.empty? || successfully_decrypted_files.empty? 
      log.info "#{CREATE_COLOR} re-encrypting edited notes:"
      tempfiles_notes = decrypted_tempfiles.zip(encrypted_notes)
      log.indent do
        tempfiles_notes.each do |(tmpfile, note_path)|
          log.info "#{PATH_COLOR} #{note_path}" if note_path
        end
      end
      log.indent { @cipher.encrypt_from_tempfiles(tempfiles_notes) } 
    end
  end

  # encrypt matching notes 
  #
  def encrypt
    return if plaintext_notes.empty?
    print_notes(:plaintext => true)
    log.indent do 
      @cipher.encrypt_files(plaintext_notes, :replace => true)
    end
  end

  # decrypt matching notes
  #
  def decrypt
    return if encrypted_notes.empty?
    print_notes(:encrypted => true)
    log.indent do
      @cipher.decrypt_files(encrypted_notes, :replace => true)
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

  # initialize to params or use defaults
  #
  def parse_init_params
    VALID_PARAMS.each do |param|
      default_const = param.to_s.upcase

     val = @params[param] || FuzzyNotes::Defaults.const_get(default_const)
     instance_variable_set("@#{param}", val) 
    end
  end

  def init_logger
    FuzzyNotes::Log.init_log(@log_level, @color)
  end

  def init_cipher
    @cipher = FuzzyNotes::Cipher.new
  end

  def init_finder
    @finder = FuzzyNotes::FuzzyFinder.new(valid_note_paths, 
                                        { :keywords => @keywords, 
                                          :extensions => valid_extensions,
                                          :full_text_search => @full_text_search })
  end

  def valid_extensions
    (@valid_extensions + @custom_extensions).uniq
  end

  def encrypted_notes
    @encrypted_notes ||= matching_notes.select { |note_path| FuzzyNotes::Cipher.encrypted?(note_path) }
  end

  def evernote_notes
    @evernote_notes ||= matching_notes.select { |note_path| FuzzyNotes::EvernoteSync.evernote?(note_path) }
  end

  def plaintext_notes
    @plaintext_notes ||= matching_notes.select { |note_path| !FuzzyNotes::Cipher.encrypted?(note_path) && 
                                                             !FuzzyNotes::EvernoteSync.evernote?(note_path) &&
                                                             !FuzzyNotes::ImageViewer.image?(note_path) }
  end

  def valid_note_paths
    valid_paths = []
    @note_paths.each do |path| 
      if File.directory?(path) 
        valid_paths << path
      else
        log.warn("note path #{PATH_COLOR} #{path} #{DEFAULT_COLOR} does not exist")
      end
    end

    if valid_paths.empty?
      log.error "no valid note paths found, exiting"
      exit
    end

    valid_paths
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
    log.info "#{keys.join(',')} notes:" unless keys.empty?
    log.indent { notes.each { |note| log.info "#{PATH_COLOR} #{note}" } }
  end

  def matching_notes(params = {})
    (@matching_notes.empty? && params[:all_if_empty]) ? @all_notes : @matching_notes
  end

end
