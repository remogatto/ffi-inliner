require 'ffi/inliner/builders/c'
require 'ffi/inliner/compilers/gxx'

module FFI; module Inliner

Builder.define Builder[:c], :cplusplus, :cxx, :cpp, 'c++' do
  def initialize(code = "", options = {})
    super(code, options) rescue nil

    use_compiler options[:use_compiler] || options[:compiler] || :gxx
  end

  def function(code, signature = nil)
    parsed = parse_signature(code)

    if signature
      parsed[:arguments] = signature[:arguments] if signature[:arguments]
      parsed[:return]    = signature[:return]    if signature[:return]
    end

    @signatures << parsed

    raw 'extern "C" {' << code << '}'
  end
end

end; end
