module FFI; module Inliner

class Builder
  attr_reader :code, :compiler, :libraries

  def initialize(name, code = "", options = {})
    @name = name
    @code = code

    options = { :compiler => Compilers::GCC, :libraries => [] }.merge(options)

    @compiler  = options[:use_compiler] || options[:compiler]
    @libraries = options[:libraries]

    @signatures = (@code && @code.empty?) ? [] : [parse_signature(@code)]
    @files      = FileManager.new(@name, @code, @libraries)
    @compiler   = @compiler.check_and_create(@files, @libraries)
  end

  def use_compiler(compiler)
    @compiler = compiler
  end

  def libraries(*libraries)
    @libraries.concat(libraries)
  end

  def map(type_map)
    @types.merge!(type_map)
  end

  def raw(code)
    @code << code
  end

  def include(path, options = {})
    delimiter = (options[:quoted] || options[:local]) ? ['"', '"'] : ['<', '>']

    raw "#include #{delimiter.first}#{path}#{delimiter.last}\n"
  end

  def function(code)
    @signatures << parse_signature(code)

    raw @compiler.function(code)
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

  def build
    unless @files.cached?
      write_files(@code, @signatures)

      @compiler.compile
      @name.instance_eval generate_ffi(@signatures)
    else
      @name.instance_eval(File.read(@files.rb_fn))
    end
  end

  private
  def to_ffi_type(c_type)
    if c_type.include? ?*
      :pointer
    else
      C_TO_FFI[c_type]
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

    types = C_TO_FFI.keys.map { |x| Regexp.escape(x) }.join('|')
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

  def generate_ffi(sig)
    ffi_code = %{
      extend FFI::Library

      ffi_lib '#{@files.so_fn}'
    }

    sig.each {|s|
      args = s.arguments.map { |arg| ":#{to_ffi_type(arg)}" }.join(', ')

      ffi_code << "attach_function '#{s.name}', [#{args}], :#{to_ffi_type(s.return)}\n"
    }

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
