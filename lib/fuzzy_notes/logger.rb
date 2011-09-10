require 'buffered_logger'

class FuzzyNotes::Log
  private_class_method :new
  LOG_LEVEL = 1
  

  def self.init_log(log_level, color)
    @log = BufferedLogger.new(STDOUT, log_level || LOG_LEVEL, default_format)
    log.disable_color unless color
  end

  def self.log
    @log ||=  BufferedLogger.new(STDOUT, LOG_LEVEL, default_format) 
  end

private
  
  def self.default_format
    { :debug => "$negative DEBUG: $reset %s",
      :warn  => "$yellow WARNING: $reset %s",
      :error => "$red ERROR: $reset %s" }
  end

end


module FuzzyNotes::Logger
  module Colors
    PATH_COLOR = "$blue"
    USER_COLOR = "$green"
    NOTE_COLOR = "$cyan"
    NUMBER_COLOR = "$red"
    CREATE_COLOR = "$green"
    DELETE_COLOR = "$red"
    IMPORT_COLOR = "$green"
    EXPORT_COLOR = "$red"
    DEFAULT_COLOR = "$reset"
  end
  include Colors

  def log
    FuzzyNotes::Log.log
  end
end
