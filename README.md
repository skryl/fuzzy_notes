## About

*fuzzy_notes* is a command line note manager with some cool features:

1. Supports Emacs/Vim/MacVim and other CLI text editors
2. Fuzzy path search and full text search across one or more note directories
3. OpenSSL encryption
4. Evernote synchronization


## Configuration

fuzzy_notes looks for a ~/.fuzzy_notes config file or the -c option to set
configuration settings. 

A config file is not required if you're ok with fuzzy_note's defaults settings
outlined below:

    :editor: vim
    :valid_extensions: ['txt', 'enc', 'html']
    :verbose: false
    :full_text_search: false
    :note_paths:
      - ~/notes

An Evernote section is required in the config file in order to use the sync tool

    :evernote:
      :note_path:       [local directory used to sync evernotes]
      :username:        [evernote username]
      :consumer_key:    [consumer key acquired through Evernote dev channel]
      :consumer_secret: [consumer secret acquired through Evernote dev channel]

Get yourself a "client application" API key from [Evernote](http://www.evernote.com/about/developer/api/#key), 
note that a "web application" API key uses OAuth to authenticate and will not work.


## Usage

    fnote [options] [keyword1, keyword2...]
      -c, --config [CONFIG]            Specify config file
      -p, --print                      Dump matching notes to stdout
      -l, --list                       List matching notes
      -i, --info                       Show statistics for matching notes
      -s, --search                     Perform a full text search when matching notes
      -v, --verbose                    Enable debug output
      -e, --encrypt                    Encrypt matching notes
      -d, --decrypt                    Decrypt matching notes
      -n, --no-color                   Turn off ANSI color
      -u, --evernote-update            Synchronize evernote directory
      -h, --help                       Show this message
