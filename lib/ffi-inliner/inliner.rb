module Inliner

  DEV_NULL = if Config::CONFIG['target_os'] =~ /mswin|mingw/
               'nul'
             else
               '/dev/null'
             end

  LIB_EXT = if Config::CONFIG['target_os'] =~ /darwin/
              '.dylib'
            elsif Config::CONFIG['target_os'] =~ /mswin|mingw/
              '.dll'
            else
              '.so'
            end

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

  @@__inliner_directory = File.expand_path(File.join('~/', '.ffi-inliner'))

  class << self
    def directory
      @@__inliner_directory
    end
  end

  class FilenameManager
    def initialize(mod, code)
      @mod = mod.name.gsub('::', '__')
      @code = code
    end
    def cached?
      exists?
    end
    def exists?
      File.exists?(c_fn)
    end
    def base_fn
      File.join(Inliner.directory, "#{@mod}_#{(Digest::MD5.new << @code).to_s[0, 4]}")      
    end
    %w(c rb log).each do |ext|
      define_method("#{ext}_fn") { "#{base_fn}.#{ext}" }
    end
    def so_fn
      "#{base_fn}#{LIB_EXT}"
    end
  end

  module Compilers
    class Compiler
      attr_reader :progname
      def self.check_and_create(fm = nil)
        compiler = new(fm) 
        unless compiler.exists?
          raise "Can't find compiler #{compiler.class}"
        else
          compiler
        end
      end
      def initialize(fm = nil)
        @fm = fm
        @progname = cmd.split.first
      end
      def compile
        raise "Compile error! See #{@fm.log_fn}" unless system(cmd)
      end
    end

    class GCC < Compiler
      def exists?
        IO.popen("#{@progname} 2>&1") { |f| f.gets } ? true : false
      end
      def ldshared
        if Config::CONFIG['target_os'] =~ /darwin/
          'gcc -dynamic -bundle -fPIC'
        else
          'gcc -shared -fPIC'
        end
      end
      def cmd
        "#{ldshared} -o \"#{@fm.so_fn}\" \"#{@fm.c_fn}\" 2>\"#{@fm.log_fn}\""
      end
    end

    class TCC < Compiler
      def exists?
        IO.popen("#{@progname}") { |f| f.gets } ? true : false
      end
      def cmd
        "tcc -shared -o \"#{@fm.so_fn}\" \"#{@fm.c_fn}\" 2>\"#{@fm.log_fn}\""
      end
    end
  end

  class Builder
    attr_reader :code
    def initialize(mod, code = "", options = {})
      make_pointer_types
      @mod = mod
      @code = code
      @sig = [parse_signature(@code)] unless @code.empty?
      options = { :compiler => Compilers::GCC }.merge(options)
      @compiler = options[:compiler]
    end

    def map(type_map)
      @types.merge!(type_map)
    end
    
    def c(code)
      (@sig ||= []) << parse_signature(code)
      @code << code 
    end

    def c_raw(code)
      @code << code
    end

    def use_compiler(compiler)
      @compiler = compiler
    end

    def build
      @fm = FilenameManager.new(@mod, @code)
      @compiler = @compiler.check_and_create(@fm)
      unless @fm.cached?
        write_files(@code, @sig)
        @compiler.compile
        @mod.instance_eval generate_ffi(@sig)
      else
        @mod.instance_eval(File.read(@fm.rb_fn))
      end
    end
    
    private

    def make_pointer_types
      @types = C_TO_FFI.dup
      C_TO_FFI.each_key do |k|
        @types["#{k} *"] = :pointer
      end    
    end

    def cached?(name, code)
      File.exists?(cname(name, code))
    end

    def to_ffi_type(c_type)
      @types[c_type]
    end

    # Based on RubyInline code by Ryan Davis
    # Copyright (c) 2001-2007 Ryan Davis, Zen Spider Software
    def strip_comments(code)
      # strip c-comments
      src = code.gsub(%r%\s*/\*.*?\*/%m, '')
      # strip cpp-comments
      src = src.gsub(%r%^\s*//.*?\n%, '')
      src = src.gsub(%r%[ \t]*//[^\n]*%, '')
      src
    end

    # Based on RubyInline code by Ryan Davis
    # Copyright (c) 2001-2007 Ryan Davis, Zen Spider Software
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
      ffi_code = <<PREAMBLE
extend FFI::Library
ffi_lib '#{@fm.so_fn}'

PREAMBLE
      sig.each do |s|
        args = s['args'].map { |arg| ":#{to_ffi_type(arg)}" }.join(',')
        ffi_code << "attach_function '#{s['name']}', [#{args}], :#{to_ffi_type(s['return'])}\n"
      end
      ffi_code
    end
    def write_c(code)
      File.open(@fm.c_fn, 'w') { |f| f << code }
    end

    def write_ffi(sig)
      File.open(@fm.rb_fn, 'w') { |f| f << generate_ffi(sig) }
    end

    def write_files(code, sig)
      write_c(code)
      write_ffi(sig)
    end

  end

  def inline(code = "", options = {})
    __inliner_make_directory
    builder = Builder.new(self, code, options)
    yield builder if block_given?
    builder.build
  end

  private

  def __inliner_make_directory
    FileUtils.mkdir(Inliner.directory) unless (File.exists?(Inliner.directory) && File.directory?(Inliner.directory))
  end

end
