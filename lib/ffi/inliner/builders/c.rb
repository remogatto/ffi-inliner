require 'ffi/inliner/compilers/tcc'
require 'ffi/inliner/compilers/gcc'

module FFI; module Inliner; module Builders

class C < Builder
  Compilers = {
    :gcc => Compilers::GCC,
    :tcc => Compilers::TCC
  }

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

  attr_reader :code, :compiler, :libraries

  def initialize(name, code = "", options = {})
    super(name, code)

    use_compiler options[:use_compiler] || options[:compiler] || :gcc

    @types     = C_TO_FFI.dup
    @libraries = options[:libraries] || []

    @signatures = (@code && @code.empty?) ? [] : [parse_signature(@code)]
  end

  def use_compiler(compiler)
    @compiler = if compiler.is_a?(Symbol)
      Compilers[compiler.downcase].new(@code, @libraries)
    else
      compiler.new(@code, @libraries)
    end
  end

  def libraries(*libraries)
    @libraries.concat(libraries)
  end

  def types(map = nil)
    map ? @types.merge!(map) : @types
  end; alias map types

  def include(path, options = {})
    delimiter = (options[:quoted] || options[:local]) ? ['"', '"'] : ['<', '>']

    raw "#include #{delimiter.first}#{path}#{delimiter.last}\n"
  end

  def function(code)
    @signatures << parse_signature(code)

    raw code
  end

  def struct(ffi_struct)
    raw %{
      typedef struct {#{
        ffi_struct.layout.fields.map {|field|
          "#{field} #{field.name};"
        }.join("\n")
      }} #{ffi_struct.class.name}
    }
  end

  private
  def to_ffi_type(c_type)
    if c_type.include? ?*
      :pointer
    else
      @types[c_type]
    end
  end

  # Based on RubyInline code by Ryan Davis
  # Copyright (c) 2001-2007 Ryan Davis, Zen Spider Software
  def strip_comments(code)
    code.gsub(%r(\s*/\*.*?\*/)m, '').
         gsub(%r(^\s*//.*?\n), '').
         gsub(%r([ \t]*//[^\n]*), '')
  end

  # Based on RubyInline code by Ryan Davis
  # Copyright (c) 2001-2007 Ryan Davis, Zen Spider Software
  def parse_signature(code)
    sig = strip_comments(code)

    sig.gsub!(/^\s*\#.*(\\\n.*)*/, '') # strip preprocessor directives
    sig.gsub!(/\{[^\}]*\}/, '{ }')     # strip {}s
    sig.gsub!(/\s+/, ' ')              # clean and collapse whitespace

    types = @types.keys.map { |x| Regexp.escape(x) }.join('|')
    sig   = sig.gsub(/\s*\*\s*/, ' * ').strip

    whole, return_type, function_name, arg_string = sig.match(/(#{types})\s*(\w+)\s*\(([^)]*)\)/).to_a

    unless whole
      raise SyntaxError, "cannot parse signature: #{sig}"
    end

    args = arg_string.split(',').map {|arg|
      # helps normalize into 'char * varname' form
      arg = arg.gsub(/\s*\*\s*/, ' * ').strip

      if /(((#{types})\s*\*?)+)\s+(\w+)\s*$/ =~ arg
        $1
      elsif arg != "void" then
        warn "WARNING: '#{arg}' not understood"
      end
    }

    ::Struct.new(:return, :name, :arguments, :arity).new(return_type, function_name, args, args.empty? ? -1 : args.length)
  end

  def ruby
    %{
      extend FFI::Library

      ffi_lib '#{@compiler.compile}'

      #{@signatures.map {|s|
        args = s.arguments.map { |arg| ":#{to_ffi_type(arg)}" }.join(', ')

        "attach_function '#{s.name}', [#{args}], :#{to_ffi_type(s.return)}"
      }.join("\n")}
    }
  end
end

end; end; end
