$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib')))
require 'ffi/inliner'

class Foo
  extend FFI::Inliner

  inline 'void say_hello (char* name) { printf("Hello, %s\n", name); }'
end

Foo.new.say_hello('foos')
