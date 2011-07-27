require 'evernote'
require 'fileutils'
require 'sanitize'
require 'digest/md5'

class FuzzyNotes::EvernoteSync
  include FuzzyNotes::Logger
  include FuzzyNotes::PasswordProtected

USER_STORE_URL = 'https://evernote.com/edam/user'
NOTE_STORE_URL = 'http://evernote.com/edam/note'
NOTE_EXT = 'html'
MAX_NOTES = 1000

  # opts should be a hash with the following keys:
  # :username, :password, :consumer_key, :consumer_secret
  #
  def initialize(params = {})
    params.merge!(:password => get_password)
    user_store = Evernote::UserStore.new(USER_STORE_URL, params)
    begin
      auth_result = user_store.authenticate
    rescue Evernote::UserStore::AuthenticationFailure
      log.error "Evernote authentication failed for #{Colors::USER} #{params[:username]}"
      return
    end

    @path = params[:note_path]
    user = auth_result.user
    @token = auth_result.authenticationToken
    note_store_url = "#{NOTE_STORE_URL}/#{user.shardId}"
    @note_store = Evernote::NoteStore.new(note_store_url)
    log.info "Evernote authentication was successful for #{Colors::USER} #{params[:username]}"
  end

  def sync
    return unless authenticated?
    unless File.directory?(@path)
      log.error("#{@path}' is not a directory!")
      return 
    end

    log.info "synchronizing with Evernote account..."
    log.indent(2) do
      # create notebook directories
      fetch_notebooks.each do |notebook|
        notebook_path = get_notebook_path(notebook[:name])
        FileUtils.mkdir(notebook_path) unless File.exists?(notebook_path)

        # write notes to files
        notebook[:notes].each do |note|
          note_path = get_note_path(notebook_path, note[:title])
          File.open(note_path, 'w') { |f| f << note[:content] }
        end
      end
    end
  end

  def self.sanitize_evernote(path)
    html = File.read(path)
    Sanitize.clean(html)
  end

private

  def fetch_notebooks
    notebooks = @note_store.listNotebooks(@token) || []
    log.info "checking for updates..."
    log.indent(2) do
      notebooks.map { |notebook| { :name => notebook.name, 
                                   :guid => notebook.guid, 
                                   :notes => fetch_notes(:name => notebook.name, :guid => notebook.guid) } }
    end
  end

  def fetch_notes(notebook_params)
    filter = Evernote::EDAM::NoteStore::NoteFilter.new 
    filter.notebookGuid = notebook_params[:guid]
    notes = @note_store.findNotes(@token, filter, nil, MAX_NOTES).notes || []
    log.indent(2) do
      notes.inject([]) do |notes, note| 
        if needs_update?(notebook_params[:name], note)
          notes << { :title => note.title, :guid => note.guid, :content => fetch_note_content(note.guid) }
        else
          notes
        end
      end
    end
  end

  def fetch_note_content(note_guid)
    note = @note_store.getNote(@token, note_guid, true, nil, nil, nil)
    log.info "updating note #{Colors::NOTE} #{note.title} #{Colors::DEFAULT} with content length #{Colors::NUMBER} #{note.contentLength}"
    note.content
  end

  def needs_update?(notebook_name, note)
    local_note_path = get_note_path(get_notebook_path(notebook_name), note.title)
    return true unless File.exists?(local_note_path)

    evernote_hash = note.contentHash
    local_note_hash = Digest::MD5.digest(File.read(local_note_path))
    log.debug "evernote_hash: #{evernote_hash}"
    log.debug "local_hash: #{local_note_hash}"
    return evernote_hash != local_note_hash 
  end

  def get_notebook_path(notebook_name)
   "#{@path}/#{sanitize_filename(notebook_name)}"
  end

  def get_note_path(notebook_path, note_title)
    "#{notebook_path}/#{sanitize_filename(note_title)}.#{NOTE_EXT}" 
  end

  def authenticated?
    !@token.nil?
  end

  def sanitize_filename(filename)
    name = filename.strip
    name.gsub!(/[^0-9A-Za-z-]/, '_')
    name.gsub!(/_+/, '_')
    name
  end

end
