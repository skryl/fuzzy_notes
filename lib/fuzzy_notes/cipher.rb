require 'gibberish'

class FuzzyNotes::Cipher
  extend FuzzyNotes::Logger
  private_class_method :new

  def self.apply_cipher(file_paths, decrypt = false)
    extension, action = decrypt ? ['.txt', 'dec'] : ['.enc', 'enc']
    password = get_password
    cipher = Gibberish::AES.new(password)

    file_paths.each do |path|
      log.info "#{action} '#{path}'"
      pathname = File.dirname(path)
      filename = File.basename(path, '.*')

      begin
        ciphertext = cipher.send(action, File.read(path))
        log.debug "[debug] writing encrypted content to: #{pathname}/#{filename}#{extension}"
        File.open("#{pathname}/#{filename}#{extension}", 'w') { |f| f << ciphertext }
        log.debug "[debug] deleting unencrypted file: #{path}"
        File.delete(path)
      rescue OpenSSL::Cipher::CipherError => e
        log.error "ERROR: #{e}"
      end
    end
  end


  def self.get_password
    printf 'Enter password (will not be shown):'
    `stty -echo`; password = STDIN.gets.strip;`stty echo`; puts
    log.debug "[debug] entered password: #{password.inspect}"
    password
  end

end
