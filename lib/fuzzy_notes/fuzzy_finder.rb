require 'find'

class FuzzyNotes::FuzzyFinder
  extend FuzzyNotes::Logger
  private_class_method :new


  def self.find(path, params = {})
    keywords, extensions, search = params.values_at(:keywords, :extensions, :full_text_search)
    match_proc = method(search ? :full_text_match? : :file_name_match?)
    log.debug "search path: #{path}"

    all_files, matching_files = [], []
    Find.find(*path) do |file_path| 
      if extension_match?(file_path, extensions) 
        all_files << file_path
        matching_files << file_path if match_proc.call(file_path, keywords)
      end
    end

    [all_files.sort, matching_files.sort]
  end


private


  def self.extension_match?(file_path, extensions)
    file_name = File.basename(file_path)
    !extensions || extensions.any? {|ext| /\.#{ext}$/ === file_name }
  end


  def self.file_name_match?(file_path, keywords)
    keywords ? keywords.any? { |name| /#{name}/ === file_path } : false
  end


  def self.full_text_match?(file_path, keywords)
    if keywords && !keywords.empty?
      file_contents = File.read(file_path)
      keywords.any? { |key| /#{key}/m === file_contents }
    else false 
    end
  end


end
