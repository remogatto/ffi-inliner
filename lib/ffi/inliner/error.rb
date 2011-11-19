class CompilationError < RuntimeError
  def initialize (path)
    @path = path

    super "compile error: see logs at #{@path}"
  end

  def log
    File.read(@path)
  end
end
