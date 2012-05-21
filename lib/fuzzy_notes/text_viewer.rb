class FuzzyNotes::TextViewer
  FuzzyNotes::TextViewer::TXT_EXT = 'txt'

  def self.read(path)
    File.read(path)
  end

end
