module Inliner

  C_TO_FFI = {
    'void' => :void,
    'char' => :char,
    'unsigned char' => :uchar,
    'int' => :int,
    'unsigned int' => :uint,
    'long' => :long,
    'unsigned long' => :ulong,
    'float' => :float,
    'double' => :double,
  }

  ErrorCallback = Proc.new { |opaque, msg|
    raise msg
  }

  @@__inliner_directory = File.expand_path(File.join('~/', '.ffi-inliner'))

  class << self
    def directory
      @__inliner_directory
    end
  end

  class FilenameManager
    def initialize(mod, function_name, code)
      @mod = mod
      @function_name = function_name
      @code = code
    end
    def cached?
      exists?
    end
    def exists?
      File.exists?(c_fn)
    end
    def base_fn
      File.join(Inliner.directory, "#{@mod}_#{@function_name}_#{(Digest::MD5.new << @code).to_s[0, 4]}")      
    end
    def c_fn
      "#{base_fn}.c"
    end
    def so_fn
      "#{base_fn}.so"
    end
    def ffi_fn
      "#{base_fn}.rb"
    end
  end

  def inline(code)
    make_directory
    make_pointer_types
    sig = parse_signature(code)

    @fm = FilenameManager.new(self, sig['name'], code)

    unless @fm.cached?
      compile(code, sig)
      instance_eval generate_ffi(sig)
    else
      eval(File.read(@fm.ffi_fn))
    end
  end

  private

  def cached?(name, code)
    File.exists?(cname(name, code))
  end

  def make_pointer_types
    @types = C_TO_FFI.dup
    C_TO_FFI.each_key do |k|
      @types["#{k} *"] = :pointer
    end    
  end

  def to_ffi_type(c_type)
    @types[c_type]
  end

  # Based on RubyInline code by Ryan Davis
  def strip_comments(code)
    # strip c-comments
    src = code.gsub(%r%\s*/\*.*?\*/%m, '')
    # strip cpp-comments
    src = src.gsub(%r%^\s*//.*?\n%, '')
    src = src.gsub(%r%[ \t]*//[^\n]*%, '')
    src
  end

  # Based on RubyInline code by Ryan Davis
  def parse_signature(code)
    sig = strip_comments(code)
    # strip preprocessor directives
    sig.gsub!(/^\s*\#.*(\\\n.*)*/, '')
    # strip {}s
    sig.gsub!(/\{[^\}]*\}/, '{ }')
    # clean and collapse whitespace
    sig.gsub!(/\s+/, ' ')
    
    # types = 'void|int|char|char\s\*|void\s\*'
    types = @types.keys.map{|x| Regexp.escape(x)}.join('|')
    sig = sig.gsub(/\s*\*\s*/, ' * ').strip

    if /(#{types})\s*(\w+)\s*\(([^)]*)\)/ =~ sig then
      return_type, function_name, arg_string = $1, $2, $3
      args = []
      arg_string.split(',').each do |arg|

        # helps normalize into 'char * varname' form
        arg = arg.gsub(/\s*\*\s*/, ' * ').strip

        if /(((#{types})\s*\*?)+)\s+(\w+)\s*$/ =~ arg then
          args.push($1)
        elsif arg != "void" then
          warn "WAR\NING: '#{arg}' not understood"
        end
      end

      arity = args.size

      return {
        'return' => return_type,
        'name'   => function_name,
        'args'   => args,
        'arity'  => arity
      }
    end

    raise SyntaxError, "Can't parse signature: #{sig}"

  end
  
  def generate_ffi(sig)
    args = sig['args'].map { |arg| ":#{to_ffi_type(arg)}" }.join(',')
    <<-code
      extend FFI::Library
      ffi_lib '#{@fm.so_fn}'
      attach_function '#{sig['name']}', [#{args}], :#{to_ffi_type(sig['return'])}
    code
  end

  def directory
    Inliner.directory
  end

  def make_directory
    FileUtils.mkdir(directory) unless (File.exists?(directory) && File.directory?(directory))
  end

  def write_c(code)
    File.open(@fm.c_fn, 'w') { |f| f << code }
  end

  def write_ffi(sig)
    File.open(@fm.ffi_fn, 'w') { |f| f << generate_ffi(sig) }
  end

  def compile(code, sig)
    state = TCC.tcc_new

    TCC.tcc_set_error_func(state, nil, ErrorCallback)
    TCC.tcc_set_output_type(state, TCC::TCC_OUTPUT_DLL)

    unless TCC.tcc_compile_string(state, code) == -1
      TCC.tcc_output_file(state, @fm.so_fn)
      write_c(code)
      write_ffi(sig)
    else
      raise 'Error during compile.'
    end

    TCC.tcc_delete(state)
  end

end
