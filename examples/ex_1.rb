$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib')))
require 'ffi-inliner'

module MyLib
  extend Inliner
  inline 'void say_hello(char* name) { printf("Hello, %s\n", name); }'
end

MyLib.say_hello('boys')

class Foo
  include MyLib
end

Foo.new.say_hello('foos')








