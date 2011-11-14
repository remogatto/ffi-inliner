module FFI; module Inliner

class Builder
  attr_reader :code

  def initialize(name, code = "")
    @name = name
    @code = code
  end

  def raw(code)
    @code << code
  end

  def ruby
    raise 'the Builder is not specialized'
  end

  def build
    @name.instance_eval ruby
  end
end

end; end
