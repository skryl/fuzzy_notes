require 'evernote'
require 'fileutils'
require 'sanitize'
require 'digest/md5'
require 'ostruct'

class FuzzyNotes::EvernoteSync
  include FuzzyNotes::Logger
  include FuzzyNotes::Authentication

  USER_STORE_URL = 'http://evernote.com/edam/user'
  NOTE_STORE_URL = 'http://evernote.com/edam/note'
  NOTE_EXT = 'html'
  MAX_NOTES = 1000

  # opts should be a hash with the following keys:
  # :username, :password, :consumer_key, :consumer_secret
  #
  def initialize(params = {})
    return unless auth_result = authenticate(params)
    @path = params[:note_path]
    @token = auth_result.authenticationToken
    @note_store = Evernote::NoteStore.new("#{NOTE_STORE_URL}/#{auth_result.user.shardId}")
  end

  def sync
    return unless authenticated? && valid_sync_path?
    log.info "syncing evernote directory #{PATH_COLOR} #{@path}"
    log.info "#{IMPORT_COLOR} synchronizing with Evernote account..."
    log.indent(2) { log.info "#{IMPORT_COLOR} checking for updates..." }
    log.indent(4) do
      notebook_structs = fetch_notebooks
      log.info "#{IMPORT_COLOR} syncing Evernote deletions..."
      log.indent(2) do
        propagate_evernote_deletions(notebook_structs)
      end
      notebook_structs.each do |notebook_struct|
        log.info "#{IMPORT_COLOR} syncing notebook #{NOTE_COLOR} #{notebook_struct.name}"
        log.indent(2) do
          create_local_notebook(notebook_struct)
          sync_notes(notebook_struct)
        end
      end
    end
  end

  def self.sanitize_evernote(path)
    html = File.read(path)
    Sanitize.clean(html)
  end

private

# evernote helpers

  def fetch_notebooks
    notebooks = @note_store.listNotebooks(@token) || []
    notebooks.map { |notebook| OpenStruct.new( { :name => notebook.name, 
                                                 :guid => notebook.guid, 
                                                 :notes => fetch_notes(notebook) } ) }
  end

  def fetch_notes(notebook)
    filter = Evernote::EDAM::NoteStore::NoteFilter.new 
    filter.notebookGuid = notebook.guid
    @note_store.findNotes(@token, filter, nil, MAX_NOTES).notes || []
  end

  def fetch_note_with_content(note)
    @note_store.getNote(@token, note.guid, true, nil, nil, nil)
  end

# sync helpers
  
  def propagate_evernote_deletions(notebook_structs)
    evernote_dir_entries = Dir["#{@path}/*"]
    evernote_dir_entries.each do |notebook_path|
      notebook_match = notebook_structs.find { |ns| sanitize_filename(ns.name) == File.basename(notebook_path) }  
      unless notebook_match
        delete_notebook!(notebook_path)
      else
        note_entries = Dir["#{notebook_path}/*"]
        note_entries.each do |note_path|
          unless notebook_match.notes.any? { |n| sanitize_filename(n.title) == File.basename(note_path, '.*') }
            delete_note!(note_path)
          end
        end
      end
    end
  end

  def delete_notebook!(notebook_path)
    log.info "#{DELETE_COLOR} notebook #{NOTE_COLOR} #{File.basename(notebook_path)} #{DELETE_COLOR} has been deleted from Evernote"
    verify_deletion(notebook_path)
  end

  def delete_note!(note_path)
    log.info "#{DELETE_COLOR} note #{NOTE_COLOR} #{File.basename(note_path, '.*')} #{DELETE_COLOR} has been deleted from Evernote"
    verify_deletion(note_path)
  end

  def sync_notes(notebook_struct)
    note_updates = \
      notebook_struct.notes.inject([[],[]]) do |(import, export), note| 
      if needs_import?(notebook_struct, note)
        import << fetch_note_with_content(note)
      elsif needs_export?(notebook_struct, note)
        export << fetch_note_with_content(note)
      end
      [import, export]
    end
    import_notes(notebook_struct, note_updates.first)
    export_notes(notebook_struct, note_updates.last)
  end

  def import_notes(notebook_struct, notes)
    notes.each do |note|
      note_path = get_note_path(notebook_struct, note)
      log.info "#{IMPORT_COLOR} importing note #{NOTE_COLOR} #{note.title} #{DEFAULT_COLOR} with content length #{NUMBER_COLOR} #{note.contentLength}"
      File.open(note_path, 'w') { |f| f << note.content }
    end
  end

  def export_notes(notebook_struct, notes)
    notes.each do |note|
      note.content = local_note_content(notebook_struct, note)
      log.info "#{EXPORT_COLOR} exporting note #{NOTE_COLOR} #{note.title} #{DEFAULT_COLOR} with content length #{NUMBER_COLOR} #{note.content.length}"
      begin
        @note_store.updateNote(@token, note)
      rescue Evernote::EDAM::Error::EDAMUserException => e
        log.error "#{e} - #{e.errorCode}"
      end
    end
  end

  def needs_import?(notebook, note)
    return true unless local_note_exists?(notebook, note)
    content_changed?(notebook, note) &&
      local_note_mod_time(notebook, note) < milli_to_time(note.updated)
  end

  def needs_export?(notebook, note)
    return false unless local_note_exists?(notebook, note)
    content_changed?(notebook, note) &&
      local_note_mod_time(notebook, note) > milli_to_time(note.updated)
  end

  def content_changed?(notebook, note)
    evernote_hash = note.contentHash
    local_note_hash = local_note_md5_hash(notebook, note)
    log.debug "evernote_hash: #{evernote_hash}"
    log.debug "local_hash: #{local_note_hash}"
    evernote_hash != local_note_hash 
  end

# local note helpers

  def local_note_mod_time(notebook, note)
    return nil unless local_note_exists?(notebook, note)
    File.stat(get_note_path(notebook, note)).mtime
  end

  def local_note_content(notebook, note)
    return nil unless local_note_exists?(notebook, note)
    File.read(get_note_path(notebook, note))
  end

  def local_note_md5_hash(notebook, note)
    return nil unless local_note_exists?(notebook, note)
    Digest::MD5.digest(local_note_content(notebook, note))
  end

  def local_note_exists?(notebook, note)
    local_note_path = get_note_path(notebook, note)
    File.exists?(local_note_path) ? true : false
  end

# file helpers

  def create_local_notebook(notebook)
    notebook_path = get_notebook_path(notebook)
    FileUtils.mkdir(notebook_path) unless File.exists?(notebook_path)
  end

  def get_notebook_path(notebook)
   "#{@path}/#{sanitize_filename(notebook.name)}"
  end

  def get_note_path(notebook, note)
    "#{get_notebook_path(notebook)}/#{sanitize_filename(note.title)}.#{NOTE_EXT}" 
  end

  def valid_sync_path?
    unless File.directory?(@path)
      log.error("#{@path}' is not a directory!")
      return false
    else true
    end
  end

  def verify_deletion(path)
    r = nil
    until r =~ /(Y|y|N|n)/ do
      log.info "Are you sure you want to delete #{path}? (Y/N) "
      r = gets
    end

    if r =~ /(Y|y)/
      FileUtils.rm_rf(path)
    end
  end

  def sanitize_filename(filename)
    name = filename.strip
    name.gsub!(/[^0-9A-Za-z-]/, '_')
    name.gsub!(/_+/, '_')
    name
  end

  def self.evernote?(path)
    File.extname(path)[1..-1] == NOTE_EXT
  end

# authentication helpers

  #TODO: ask for all missing params
  def authenticate(params)
    params.merge!(:password => get_password)
    user_store = Evernote::UserStore.new(USER_STORE_URL, params)
    begin
      token = user_store.authenticate
      log.info "Evernote authentication was successful for #{USER_COLOR} #{params[:username]}"
      token
    rescue Evernote::UserStore::AuthenticationFailure
      log.error "Evernote authentication failed for #{USER_COLOR} #{params[:username]}"
      return
    end
  end

  def authenticated?
    !@token.nil?
  end

# random

  def milli_to_time(milli)
    Time.at(milli/1000.0)
  end

end
