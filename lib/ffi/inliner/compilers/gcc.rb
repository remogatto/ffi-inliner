module FFI; module Inliner; module Compilers

class GCC < Compiler
  def self.exists?
    !!::IO.popen('gcc 2>&1') { |f| f.read(1) }
  end

  def initialize (code, libraries = [])
    super('gcc')

    @code      = code
    @libraries = libraries
  end

  def digest
    Digest::SHA256.hexdigest(@code)
  end

  def input
    File.join(Inliner.directory, "#{digest}.c").tap {|path|
      File.open(path, 'w') { |f| f.write(@code) } unless File.exists?(path)
    }
  end

  def output
    File.join(Inliner.directory, "#{digest}.#{LIB_EXT}")
  end

  def log
    File.join(Inliner.directory, "#{digest}.log")
  end

  def ldshared
    if RbConfig::CONFIG['target_os'] =~ /darwin/
      'gcc -dynamic -bundle -fPIC'
    else
      'gcc -shared -fPIC'
    end
  end

  def compile
    return output if File.exists?(output)

    unless system(if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
      %{sh -c '#{ldshared} -o "#{output}" "#{input}" #{libs}' 2>"#{log}"}
    else
      %{#{ldshared} -o "#{output}" "#{input}" #{libs} 2>"#{log}"}
    end)
      raise "compile error: see logs at #{log}"
    end

    output
  end

  private
  def libs
    @libraries.map { |lib| "-l#{lib}" }.join(' ')
  end
end

end; end; end
