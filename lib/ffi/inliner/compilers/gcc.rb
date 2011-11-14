module FFI; module Inliner; module Compilers

class GCC < Compiler
  def exists?
    !!IO.popen("#{@name} 2>&1") { |f| f.read(1) }
  end

  def ldshared
    if RbConfig::CONFIG['target_os'] =~ /darwin/
      'gcc -dynamic -bundle -fPIC'
    else
      'gcc -shared -fPIC'
    end
  end

  def cmd
    if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
      "sh -c ' #{ldshared} -o \"#{@files.so_fn}\" \"#{@files.c_fn}\" #{libs}' 2>\"#{@files.log_fn}\""
    else
      "#{ldshared} #{libs} -o \"#{@files.so_fn}\" \"#{@files.c_fn}\" #{libs} 2>\"#{@files.log_fn}\""
    end
  end
end

end; end; end
