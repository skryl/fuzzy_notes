require 'gibberish'

class FuzzyNotes::Cipher
  include FuzzyNotes::Logger
  include FuzzyNotes::PasswordProtected

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
      file_paths.each do |path| 
        if self.class.encrypted?(path)
          log.warn "#{Colors::PATH} #{path} #{Colors::DEFAULT} is already encrypted, skipping"
          next
        end
        process_file(path, cipher, opts)
      end
    when String
      process_file(file_paths, cipher, opts)
    end
  end

  def process_file(path, cipher, opts) 
    begin
      log.debug "#{@action} '#{path}'"
      content = cipher.send(@action, File.read(path))
      replace_file!(path, content) if opts[:replace] 
      content
    rescue OpenSSL::Cipher::CipherError => e
      log.error e
    end
  end

  def replace_file!(path, contents)
    dirname  = File.dirname(path)
    filename = File.basename(path, '.*')

    log.info "#{Colors::CREATE} writing #{decrypt? ? 'un' : ''}encrypted file: #{Colors::PATH} #{dirname}/#{filename}.#{extension}"
    File.open("#{dirname}/#{filename}.#{extension}", 'w') { |f| f << contents }

    log.info "#{Colors::DELETE} deleting #{decrypt? ? '' : 'un'}encrypted file: #{Colors::PATH} #{path}"
    File.delete(path)
  end

  def extension
    decrypt? ? PLAINTEXT_EXT : CIPHERTEXT_EXT
  end

  def decrypt?
    @action == :dec
  end

  def self.encrypted?(path)
    File.extname(path)[1..-1] == CIPHERTEXT_EXT
  end


end
