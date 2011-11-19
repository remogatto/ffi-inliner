module FFI; module Inliner

Compiler.define :tcc do
  def exists?
    `tcc -v 2>&1'`; $?.success?
  end

  def compile (code, libraries = [])
    @code      = code
    @libraries = libraries

    return output if File.exists?(output)

    unless system(if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
      "sh -c '#{ldshared} #{libs} -o #{output.shellescape} #{input.shellescape}' 2>#{log.shellescape}"
    else
      "#{ldshared} #{libs} -o #{output.shellescape} #{input.shellescape} 2>#{log.shellescape}"
    end)
      raise "compile error: see logs at #{log}"
    end

    output
  end

  private
  def digest
    Digest::SHA1.hexdigest(@code + @libraries.to_s + @options)
  end

  def input
    File.join(Inliner.directory, "#{digest}.c").tap {|path|
      File.open(path, 'w') { |f| f.write(@code) } unless File.exists?(path)
    }
  end

  def output
    File.join(Inliner.directory, "#{digest}.#{Compiler::Extension}")
  end

  def log
    File.join(Inliner.directory, "#{digest}.log")
  end

  def ldshared
    if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
      "tcc -rdynamic -shared -fPIC #{options}"
    else
      "tcc -shared #{options}"
    end
  end

  def libs
    @libraries.map { |lib| "-l#{lib}".shellescape }.join(' ')
  end
end

end; end
