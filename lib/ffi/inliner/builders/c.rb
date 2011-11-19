require 'ffi/inliner/compilers/tcc'
require 'ffi/inliner/compilers/gcc'

module FFI; module Inliner

Builder.define :c do
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

  def initialize(code = nil, options = {})
    super(code)

    @types     = ToFFI.dup
    @libraries = options[:libraries] || []

    @signatures = []

    use_compiler options[:use_compiler] || options[:compiler] || :gcc

    @signatures << parse_signature(code) if code && !code.empty?
  end

  def libraries(*libraries)
    @libraries.concat(libraries)
  end

  def types(map = nil)
    map ? @types.merge!(map) : @types
  end; alias map types

  def raw(code, no_line = false)
    return super(code) if no_line

    whole, path, line = caller.find { |line| line !~ /ffi-inliner/ }.match(/^(.*?):(\d+):in/).to_a

    super "#line #{line.to_i - 1} #{path.inspect}\n" << code
  end

  alias c_raw raw

  def include(path, options = {})
    delimiter = (options[:quoted] || options[:local]) ? ['"', '"'] : ['<', '>']

    raw "#include #{delimiter.first}#{path}#{delimiter.last}\n", true
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
    }, true
  end

  def to_ffi_type(type)
    if type.is_a?(Symbol)
      type
    elsif @types[type]
      @types[type]
    elsif type.include? ?*
      :pointer
    elsif (FFI.find_type(type.to_sym) rescue false)
      type
    else
      raise "type #{type} not supported"
    end.to_sym
  end

  def shared_object
    @compiler.compile(@code, @libraries)
  end

  def signatures
    @signatures
  end

private

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

    raise SyntaxError, "cannot parse signature: #{sig}" unless whole

    args = arg_string.split(',').map {|arg|
      # helps normalize into 'char * varname' form
      arg = arg.gsub(/\s*\*\s*/, ' * ').strip

      whole, type = arg.gsub(/\s*\*\s*/, ' * ').strip.match(/(((.*?(?:\ \*)?)\s*\*?)+)\s+(\w+)\s*$/).to_a

      type
    }

    Signature.new(return_type, function_name, args, args.empty? ? -1 : args.length)
  end
end

end; end
