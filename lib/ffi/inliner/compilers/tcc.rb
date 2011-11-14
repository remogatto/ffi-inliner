module FFI; module Inliner; module Compilers

class TCC < Compiler
  def exists?
    !!IO.popen("#{@name}") { |f| f.read(1) }
  end

  def cmd
    if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
      "tcc -rdynamic -shared #{libs} -o \"#{@files.so_fn}\" \"#{@files.c_fn}\" 2>\"#{@files.log_fn}\""
    else
      "tcc -shared #{libs} -o \"#{@files.so_fn}\" \"#{@files.c_fn}\" 2>\"#{@files.log_fn}\""
    end
  end
end

end; end; end
