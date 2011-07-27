module FuzzyNotes::PasswordProtected

  def get_password
    printf 'Enter password (will not be shown):'
    `stty -echo`; password = STDIN.gets.strip;`stty echo`; puts
    log.debug "entered password: #{password.inspect}"
    password
  end

end
