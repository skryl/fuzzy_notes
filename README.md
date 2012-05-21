## About

*fuzzy_notes* is a command line document viewer with some cool features:

1. Supports Emacs/Vim/MacVim and other CLI text editors
2. Supports viewing image files using a user specified CLI viewer (eg. open, display)
3. Fuzzy path search and full text search across one or more note directories
4. OpenSSL encryption for text notes
5. Evernote synchronization


## Configuration

*fuzzy_notes* looks for a ~/.fuzzy_notes config file or the -c option and a
config file path. A config file is not required if you're ok with the default
settings:

    :editor: vim
    :viewer: open
    :valid_extensions: ["txt", "enc", "txt", "html", "tif", "tiff", "gif", "jpeg", "jpg", "png", "pdf"]
    :verbose: false
    :full_text_search: false
    :note_paths:
      - ~/notes

An Evernote section is required in the config file in order to use the evernote sync tool

    :evernote:
      :note_path:       [local directory used to sync evernotes]
      :username:        [evernote username]
      :consumer_key:    [consumer key acquired through Evernote dev channel]
      :consumer_secret: [consumer secret acquired through Evernote dev channel]

You need to get a "client application" API key from [Evernote](http://www.evernote.com/about/developer/api/#key), 
note that a "web application" API key uses OAuth to authenticate and will not work.


## Usage

    Usage: fnote [options] [keyword1, keyword2...]
        -c, --config [CONFIG]            Specify config file
        -t, --editor [EDITOR]            Editor of choice
        -a, --add-path [PATH]            Add a note path to the config file
        -r, --rm-path [PATH]             Remove a note path from the config file
        -s, --search                     Perform a full text search when matching notes
        -p, --preview                    Dump matching notes to stdout or preview images
        -l, --list                       List all or matching notes
        -i, --info                       Show stats for matching notes
        -e, --encrypt                    Encrypt matching notes
        -d, --decrypt                    Decrypt matching notes
        -v, --verbose                    Enable debug output
        -u, --update-evernotes           Synchronize evernote directory
            --no-color                   Turn off ANSI color
        -h, --help                       Show usage
