module FFI; module Inliner

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

  def initialize(target, code = "")
    @target = target
    @code   = code
  end

  def use_compiler(compiler)
    @compiler = Compiler[compiler]
  end

  def raw(code)
    @code << code
  end

  def ruby
    raise 'the Builder has not been specialized'
  end

  def build
    @target.instance_eval ruby
  end
end

end; end

require 'ffi/inliner/builders/c'
require 'ffi/inliner/builders/cpp'
