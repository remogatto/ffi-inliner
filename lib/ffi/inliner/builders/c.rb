require 'ffi/inliner/compilers/tcc'
require 'ffi/inliner/compilers/gcc'

module FFI; module Inliner; module Builders

class C < Builder
  Compilers = {
    :gcc => Compilers::GCC,
    :tcc => Compilers::TCC
  }

  ToFFI = {
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

    @types     = ToFFI.dup
    @libraries = options[:libraries] || []

    @signatures = (code && code.empty?) ? [] : [parse_signature(code)]

    use_compiler options[:use_compiler] || options[:compiler] || :gcc
  end

  def use_compiler(compiler)
    @compiler = if compiler.is_a?(Symbol)
      self.class::Compilers[compiler.downcase].new(@code, @libraries)
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

  alias c_raw raw

  def include(path, options = {})
    delimiter = (options[:quoted] || options[:local]) ? ['"', '"'] : ['<', '>']

    raw "#include #{delimiter.first}#{path}#{delimiter.last}\n"
  end

  def function(code, signature = nil)
    parsed = parse_signature(code)

    if signature
      parsed[:arguments] = signature[:arguments] if signature[:arguments]
      parsed[:return]    = signature[:return]    if signature[:return]
    end

    @signatures << parsed

    raw code
  end; alias c function

  def struct(ffi_struct)
    raw %{
      typedef struct {#{
        ffi_struct.layout.fields.map {|field|
          "#{field} #{field.name};"
        }.join("\n")
      }} #{ffi_struct.class.name}
    }
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

  private
  def to_ffi_type(type)
    if type.is_a?(Symbol)
      type
    elsif @types[type]
      @types[type]
    elsif type.include? ?*
      :pointer
    elsif (FFI.find_type(type.to_sym) rescue false)
      type.to_sym
    else
      raise "type #{type} not supported"
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
    sig.gsub!(/\s*\{.*/m, '')          # strip function body
    sig.gsub!(/\s+/, ' ')              # clean and collapse whitespace
    sig.gsub!(/\s*\*\s*/, ' * ')       # clean pointers
    sig.gsub!(/\s*const\s*/, '')       # remove const
    sig.strip!

    whole, return_type, function_name, arg_string = sig.match(/(.*?(?:\ \*)?)\s*(\w+)\s*\(([^)]*)\)/).to_a

    unless whole
      raise SyntaxError, "cannot parse signature: #{sig}"
    end

    args = arg_string.split(',').map {|arg|
      # helps normalize into 'char * varname' form
      arg = arg.gsub(/\s*\*\s*/, ' * ').strip

      whole, type = arg.gsub(/\s*\*\s*/, ' * ').strip.match(/(((.*?(?:\ \*)?)\s*\*?)+)\s+(\w+)\s*$/).to_a

      type
    }

    ::Struct.new(:return, :name, :arguments, :arity).new(return_type, function_name, args, args.empty? ? -1 : args.length)
  end
end

end; end; end
