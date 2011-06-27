require 'buffered_logger'

class FuzzyNotes::Log
  private_class_method :new
  LOG_LEVEL = 1

  def self.init_log(log_level)
    @log = BufferedLogger.new(STDOUT, log_level)
  end

  def self.log
    @log ||=  BufferedLogger.new(STDOUT, LOG_LEVEL) 
  end
end


module FuzzyNotes::Logger
  def log
    FuzzyNotes::Log.log
  end
end
