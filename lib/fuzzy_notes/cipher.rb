require 'gibberish'

class FuzzyNotes::Cipher
  include FuzzyNotes::Logger
  include FuzzyNotes::Authentication

  PLAINTEXT_EXT  = 'txt'
  CIPHERTEXT_EXT = 'enc'
  TMP_FILE_PREFIX = 'fuzzy_notes'
  ENCRYPT_METHOD_MATCHER = /\Aencrypt_(data|file|files|from_tempfile|from_tempfiles)\Z/
  DECRYPT_METHOD_MATCHER = /\Adecrypt_(data|file|files|to_tempfile|to_tempfiles)\Z/

private

  def method_missing(method_sym, *args)
    method_name = method_sym.to_s
    log.debug "args: #{args.inspect}"
    last_arg = args.last
    opts = last_arg.is_a?(Hash) ? last_arg : {}

    case method_name
    when ENCRYPT_METHOD_MATCHER
      @action = :enc
    when DECRYPT_METHOD_MATCHER
      @action = :dec
    else super
    end

    case $1
    when 'data'
      process_data(args.first, Gibberish::AES.new(get_password))
    when 'file'
      process_file(args.first, Gibberish::AES.new(get_password), opts)
    when 'files'
      cipher = Gibberish::AES.new(get_password)
      args.first.map { |path| process_file(path, cipher, opts) }
    when 'to_tempfile', 'from_tempfile'
      self.send(method_sym, args.first, Gibberish::AES.new(get_password))
    when 'to_tempfiles', 'from_tempfiles'
      cipher = Gibberish::AES.new(get_password)
      args.first.map { |file_path| self.send(method_name[0..-2], *file_path, cipher) }
    end
  end

  def process_file(path, cipher, opts = {}) 
    return unless path && valid_filename?(path)
    log.info "#{decrypt? ? 'de' : 'en'}crypting file #{PATH_COLOR} #{path}"
    content = File.read(path)
    return unless valid_content?(content)

    processed_content = process_data(content, cipher)
    replace_file!(path, processed_content) if processed_content && opts[:replace]
    processed_content
  end

  def process_data(data, cipher)
    begin
      cipher.send(@action, data) unless data.blank?
    rescue OpenSSL::Cipher::CipherError => e
      log.error e
      nil
    end
  end

  def replace_file!(path, contents)
    dirname  = File.dirname(path)
    filename = File.basename(path, '.*')

    log.info "#{CREATE_COLOR} writing #{decrypt? ? 'un' : ''}encrypted file: #{PATH_COLOR} #{dirname}/#{filename}.#{extension}"
    File.open("#{dirname}/#{filename}.#{extension}", 'w') { |f| f << contents }

    log.info "#{DELETE_COLOR} deleting #{decrypt? ? '' : 'un'}encrypted file: #{PATH_COLOR} #{path}"
    File.delete(path)
  end

  def decrypt_to_tempfile(file_path, cipher)
    content = process_file(file_path, cipher)
    content && Tempfile.open(TMP_FILE_PREFIX) do |tmp_file|
        tmp_file << content
        tmp_file.path
    end
  end

  def encrypt_from_tempfile(tmp_file, file_path, cipher)
    content = File.read(tmp_file)
    content && File.open(file_path, 'w') do |file|
      file << process_data(content, cipher)
    end
  end

  def valid_filename?(path)
    if encrypt? && self.class.encrypted?(path) || decrypt? && !self.class.encrypted?(path)
      log.warn "#{PATH_COLOR} #{path} #{DEFAULT_COLOR} is #{encrypt? ? 'already' : 'not'} encrypted, skipping"
      return false
    end
    true
  end

  def valid_content?(content)
    if content.blank?
      log.warn "file is empty, skipping"
      return false
    end
    true
  end

  def extension
    decrypt? ? PLAINTEXT_EXT : CIPHERTEXT_EXT
  end

  def encrypt?
    @action == :enc
  end

  def decrypt?
    @action == :dec
  end

  def self.encrypted?(path)
    File.extname(path)[1..-1] == CIPHERTEXT_EXT
  end

end
