require 'evernote'
require 'fileutils'

class FuzzyNotes::EvernoteSync
  include FuzzyNotes::Logger

USER_STORE_URL = 'https://evernote.com/edam/user'
NOTE_STORE_URL = 'http://evernote.com/edam/note'
MAX_NOTES = 1000
CONFIG = { :username => 'rut216',
           :password => '',
           :consumer_key => 'rut216',
           :consumer_secret => '160988912605c36c' }

  # opts should be a hash with the following keys:
  # :username, :password, :consumer_key, :consumer_secret
  #
  def initialize(opts = {})
    user_store = Evernote::UserStore.new(USER_STORE_URL, CONFIG)
    auth_result = user_store.authenticate
    user = auth_result.user
    @token = auth_result.authenticationToken
    note_store_url = "#{NOTE_STORE_URL}/#{user.shardId}"
    @note_store = Evernote::NoteStore.new(note_store_url)
    log.info "Evernote authentication was successful for $red #{user.username}"
  end

  def sync(path)
    raise "#{path}' is not a directory!" unless File.directory?(path)

    # Recreate evernote directory
    FileUtils.rm_rf(path)
    FileUtils.mkdir(path)

    # create notebook directories
    fetch_notebooks.each do |notebook|
      notebook_path = "#{path}/#{notebook[:name]}"
      FileUtils.mkdir(notebook_path)

      # write notes to files
      notebook[:notes].each do |note|
        note_path = "#{notebook_path}/#{note[:title]}.html"
        File.open(note_path, 'w') { |f| f << note[:content] }
      end
    end
  end

private

  def fetch_notebooks
    notebooks = @note_store.listNotebooks(@token) || []
    log.info "Found #{notebooks.size} notebooks"
    notebooks.map { |notebook| { :name => notebook.name, 
                                 :guid => notebook.guid, 
                                 :notes => fetch_notes(:name => notebook.name, :guid => notebook.guid) } }
  end

  def fetch_notes(notebook_params)
    filter = Evernote::EDAM::NoteStore::NoteFilter.new 
    filter.notebookGuid = notebook_params[:guid]
    notes = @note_store.findNotes(@token, filter, nil, MAX_NOTES).notes || []
    log.info "Found #{notes.size} notes in notebook '#{notebook_params[:name]}'"
    notes.map { |note| { :title => note.title, :guid => note.guid, :content => fetch_note_content(note.guid) } }
  end

  def fetch_note_content(note_guid)
    note = @note_store.getNote(@token, note_guid, true, nil, nil, nil)
    log.info "Found note '#{note.title}' with content length #{note.contentLength}"
    note.content
  end

end
