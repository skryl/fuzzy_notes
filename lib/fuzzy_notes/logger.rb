require 'buffered_logger'

class FuzzyNotes::Log
  private_class_method :new
  LOG_LEVEL = 1
  

  def self.init_log(log_level)
    @log = BufferedLogger.new(STDOUT, log_level || LOG_LEVEL, default_format)
  end

  def self.log
    @log ||=  BufferedLogger.new(STDOUT, LOG_LEVEL, default_format) 
  end

private
  
  def self.default_format
    { :debug => "$negative DEBUG: $white %s",
      :info  => "$green INFO: $white %s",
      :warn  => "$yellow WARNING: $white %s",
      :error => "$red ERROR: $white %s" }
  end

end


module FuzzyNotes::Logger
  def log
    FuzzyNotes::Log.log
  end
end
