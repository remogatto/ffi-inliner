module FFI; module Inliner

Signature = ::Struct.new(:return, :name, :arguments, :arity)

class Builder
  @builders = []

  def self.[](name)
    return name if name.is_a?(Builder)

    @builders.find {|builder|
      builder.name.downcase == name.downcase ||
      builder.aliases.any? { |ali| ali.downcase == name.downcase }
    }
  end

  def self.define (name, *aliases, &block)
    inherit_from = self

    if name.is_a?(Builder)
      name = name.class
    end

    if name.is_a?(Class)
      inherit_from = name
      name         = aliases.shift
    end

    @builders << Class.new(inherit_from, &block).tap {|k|
      k.instance_eval {
        define_singleton_method :name do name end
        define_singleton_method :aliases do aliases end
      }
    }
  end

  attr_reader :code, :compiler

  def initialize(code = "")
    @code  = code
    @evals = []
  end

  def use_compiler(compiler)
    @compiler = Compiler[compiler]
  end

  def raw(code)
    @code << code
  end

  def eval(&block)
    @evals << block
  end

  def to_ffi_type(type)
    raise 'the Builder has not been specialized'
  end

  def shared_object
    raise 'the Builder has not been specialized'
  end

  def signatures
    raise 'the Builder has not been specialized'
  end

  def symbols
    signatures.map { |s| s.name.to_sym }
  end

  def build
    builder = self
    blocks  = @evals

    mod = Module.new
    mod.instance_eval {
      extend FFI::Library

      ffi_lib builder.shared_object

      blocks.each { |block| instance_eval &block }

      builder.signatures.each {|s|
        attach_function s.name, s.arguments.compact.map {|a|
          builder.to_ffi_type(a, self)
        }, builder.to_ffi_type(s.return, self)
      }
    }

    mod
  end
end

end; end

require 'ffi/inliner/builders/c'
require 'ffi/inliner/builders/cpp'
