module FFI

module Inliner
  NULL =
    if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
      'nul'
    else
      '/dev/null'
    end

  LIB_EXT =
    if RbConfig::CONFIG['target_os'] =~ /darwin/
      '.dylib'
    elsif RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
      '.dll'
    else
      '.so'
    end

  C_TO_FFI = {
    'void'          => :void,
    'char'          => :char,
    'unsigned char' => :uchar,
    'int'           => :int,
    'unsigned int'  => :uint,
    'long'          => :long,
    'unsigned long' => :ulong,
    'float'         => :float,
    'double'        => :double,
  }

  def self.directory
    @inliner_directory ||= File.expand_path(File.join('~/', '.ffi-inliner'))
  end

  class FilenameManager
    def initialize(mod, code, libraries)
      @mod = mod.name.gsub(/[:#<>\/]/, '_')
      @code = code
      @libraries = libraries
    end
    def cached?
      exists?
    end
    def exists?
      File.exists?(c_fn)
    end
    def base_fn
      File.join(Inliner.directory, "#{@mod}_#{(Digest::MD5.new << @code << @libraries.to_s).to_s[0, 4]}")
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
      def self.check_and_create(fm = nil, libraries = nil)
        compiler = new(fm, libraries)
        unless compiler.exists?
          raise "Can't find compiler #{compiler.class}"
        else
          compiler
        end
      end
      def initialize(fm = nil, libraries = nil)
        @fm = fm
        @libraries = libraries
        # ignore sh -c '
        @progname = cmd.split.reject{|part| ["'", "sh", "-c"].include? part}[0]
      end
      def compile
        puts 'running:' + cmd if $VERBOSE
        raise "Compile error! See #{@fm.log_fn}" unless system(cmd)
      end
      private
      def libs
        @libraries.inject("") { |str, lib| str << "-l#{lib} " } if @libraries
      end
    end

    class GCC < Compiler
      def exists?
        IO.popen("#{@progname} 2>&1") { |f| f.gets } ? true : false
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
          "sh -c ' #{ldshared} -o \"#{@fm.so_fn}\" \"#{@fm.c_fn}\" #{libs}' 2>\"#{@fm.log_fn}\""
        else
          "#{ldshared} #{libs} -o \"#{@fm.so_fn}\" \"#{@fm.c_fn}\" #{libs} 2>\"#{@fm.log_fn}\""
        end
      end
    end

    class GPlusPlus < GCC

      def ldshared
        if RbConfig::CONFIG['target_os'] =~ /darwin/
          'g++ -dynamic -bundle -fPIC'
        else
          'g++ -shared -fPIC'
        end
      end
    end

    class TCC < Compiler
      def exists?
        IO.popen("#{@progname}") { |f| f.gets } ? true : false
      end
      def cmd
        if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
          "tcc -rdynamic -shared #{libs} -o \"#{@fm.so_fn}\" \"#{@fm.c_fn}\" 2>\"#{@fm.log_fn}\""
        else
          "tcc -shared #{libs} -o \"#{@fm.so_fn}\" \"#{@fm.c_fn}\" 2>\"#{@fm.log_fn}\""
        end
      end
    end
  end

  class Builder
    attr_reader :code, :compiler, :libraries
    def initialize(mod, code = "", options = {})
      make_pointer_types
      @mod = mod
      @code = code
      @sig = [parse_signature(@code)] unless @code.empty?

      options = { :use_compiler => Compilers::GCC, :libraries => [] }.merge(options)

      @compiler = options[:use_compiler]
      @libraries = options[:libraries]
    end

    def map(type_map)
      @types.merge!(type_map)
    end

    def include(fn, options = {})
      options[:quoted] ? @code << "#include \"#{fn}\"\n" : @code << "#include <#{fn}>\n"
    end

    def libraries(*libraries)
      @libraries.concat(libraries)
    end

    def c(code)
      (@sig ||= []) << parse_signature(code)
      @code << (@compiler == Compilers::GPlusPlus ? "extern \"C\" {\n#{code}\n}" : code )
    end

    def c_raw(code)
      @code << code
    end

    def use_compiler(compiler)
      @compiler = compiler
    end

    def struct(ffi_struct)
      @code << "typedef struct {"
      ffi_struct.layout.fields.each do |field|
        @code << "#{field} #{field.name};\n"
      end
      @code << "} #{ffi_struct.class.name}"
    end

    def build
      @fm = FilenameManager.new(@mod, @code, @libraries)
      @compiler = @compiler.check_and_create(@fm, @libraries)
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

      unless sig.nil?
        sig.each do |s|
          args = s['args'].map { |arg| ":#{to_ffi_type(arg)}" }.join(',')
          ffi_code << "attach_function '#{s['name']}', [#{args}], :#{to_ffi_type(s['return'])}\n"
        end
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

end
