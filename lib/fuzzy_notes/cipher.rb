require 'gibberish'

class FuzzyNotes::Cipher
  include FuzzyNotes::Logger

  PLAINTEXT_EXT  = 'txt'
  CIPHERTEXT_EXT = 'enc'

  def encrypt(file_paths, opts = {})
    @action = :enc
    apply_cipher(file_paths, opts)
  end

  def decrypt(file_paths, opts = {})
    @action = :dec
    apply_cipher(file_paths, opts)
  end

private

  def apply_cipher(file_paths, opts)
    cipher = Gibberish::AES.new(get_password)
    case file_paths
    when Array
      file_paths.each { |path| process_file(path, cipher, opts) }
    when String
      process_file(file_paths, cipher, opts)
    end
  end

  def process_file(path, cipher, opts) 
    begin
      log.debug "#{@action} '#{path}'"
      content  = cipher.send(@action, File.read(path))
      replace_file!(path, content) if opts[:replace] 
      content
    rescue OpenSSL::Cipher::CipherError => e
      log.error e
    end
  end

  def replace_file!(path, contents)
    dirname  = File.dirname(path)
    filename = File.basename(path, '.*')

    log.debug "writing #{decrypt? ? 'un' : ''}encrypted content to: #{dirname}/#{filename}.#{extension}"
    File.open("#{dirname}/#{filename}.#{extension}", 'w') { |f| f << contents }

    log.debug "deleting #{decrypt? ? '' : 'un'}encrypted file: #{path}"
    File.delete(path)
  end

  def extension
    decrypt? ? PLAINTEXT_EXT : CIPHERTEXT_EXT
  end

  def decrypt?
    @action == :dec
  end

  def get_password
    printf 'Enter password (will not be shown):'
    `stty -echo`; password = STDIN.gets.strip;`stty echo`; puts "\n\n"
    log.debug "entered password: #{password.inspect}"
    password
  end


end
