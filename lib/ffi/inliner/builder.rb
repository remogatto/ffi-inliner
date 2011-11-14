module FFI; module Inliner

class Builder
  attr_reader :code, :compiler, :libraries

  def initialize(name, code = "", options = {})
    make_pointer_types

    @name = name
    @code = code
    @sig  = [parse_signature(@code)] unless @code.empty?

    options = { :compiler => Compilers::GCC, :libraries => [] }.merge(options)

    @compiler  = options[:compiler]
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
    @files    = FilenameManager.new(@name, @code, @libraries)
    @compiler = @compiler.check_and_create(@files, @libraries)

    unless @files.cached?
      write_files(@code, @sig)

      @compiler.compile
      @name.instance_eval generate_ffi(@sig)
    else
      @name.instance_eval(File.read(@files.rb_fn))
    end
  end

  private
  def make_pointer_types
    @types = C_TO_FFI.dup

    C_TO_FFI.each_key {|k|
      @types["#{k} *"] = :pointer
    }
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
    ffi_code = %{
      extend FFI::Library
      ffi_lib '#{@files.so_fn}'
    }

    unless sig.nil?
      sig.each do |s|
        args = s['args'].map { |arg| ":#{to_ffi_type(arg)}" }.join(',')

        ffi_code << "attach_function '#{s['name']}', [#{args}], :#{to_ffi_type(s['return'])}\n"
      end
    end

    ffi_code
  end

  def write_c(code)
    File.open(@files.c_fn, 'w') { |f| f << code }
  end

  def write_ffi(sig)
    File.open(@files.rb_fn, 'w') { |f| f << generate_ffi(sig) }
  end

  def write_files(code, sig)
    write_c(code)
    write_ffi(sig)
  end
end

end; end
