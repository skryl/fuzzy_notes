require 'find'

class FuzzyNotes::FuzzyFinder
  include FuzzyNotes::Logger

  attr_reader :path, :all_files, :matching_files, :keywords, :extensions, :full_text_search

  def initialize(path, params = {})
    @path = path
    log.debug "search path: #{path}"

    @keywords, @extensions, @search_type = params.values_at(:keywords, :extensions, :full_text_search)
    self.refresh
  end

  def refresh
    clear_results
    Find.find(*@path) do |file_path| 
      if !File.directory?(file_path) && extension_match?(file_path)
        @all_files << file_path
        @matching_files << file_path if file_match_proc.call(file_path)
      end
    end
  end

private

  def clear_results
    @all_files, @matching_files = [], []
  end

  def file_match_proc
    method(@search_type ? :full_text_match? : :file_name_match?)
  end

  def extension_match?(file_path)
    file_name = File.basename(file_path)
    !@extensions || @extensions.any? {|ext| /\.#{ext}$/ === file_name }
  end

  def file_name_match?(file_path)
    @keywords ? @keywords.any? { |name| /#{name}/ === file_path } : false
  end

  def full_text_match?(file_path)
    if @keywords && !@keywords.empty?
      file_contents = File.read(file_path)
      @keywords.any? { |key| /#{key}/m === file_contents }
    else false 
    end
  end


end
