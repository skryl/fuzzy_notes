require 'find'

class FuzzyFinder
  private_class_method :new

  def self.find(path, opts = {})
    keywords, extensions = opts.values_at(:keywords, :extensions)
    all_files, matching_files = [], []

    Find.find(*path) do |file_path| 
      file_name = File.basename(file_path)

      if !extensions || extensions.any? {|ext| /\.#{ext}$/ === file_name } 
        all_files << file_path
        if keywords && keywords.any? {|name| /#{name}/ === file_path }
          Find.prune if File.directory?(file_path)
          matching_files << file_path 
        end
      end
    end

    [all_files.sort, matching_files.sort]
  end

end
