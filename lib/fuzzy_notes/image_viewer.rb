class FuzzyNotes::ImageViewer
  IMG_EXTS = ['tif', 'tiff', 'gif', 'jpeg', 'jpg', 'png', 'pdf']

  def self.display(viewer, path)
    `#{viewer} #{path}`
  end

  def self.image?(path)
    IMG_EXTS.include?(File.extname(path)[1..-1])
  end

end
