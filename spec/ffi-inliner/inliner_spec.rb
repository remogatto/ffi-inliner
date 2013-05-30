require File.expand_path(File.join(File.dirname(__FILE__), "../spec_helper"))

describe 'Inliner' do

  before do
    module Foo
      extend Inliner
    end
    @cache_dir = File.join(SPEC_BASEPATH, 'ffi-inliner/cache')
    Inliner.stub!(:directory).and_return(@cache_dir)
  end
  
  after do
    FileUtils.rm_rf(@cache_dir)
  end

  it 'should extend the module with inline methods' do
    module Foo
      inline <<-code
      long factorial(int max) 
      {
          int i = max, result = 1;
          while (i >= 2) { result *= i--; }
          return result;
      }
      code
      inline 'int simple_math() { return 1 + 1; }'
    end

    Foo.factorial(4).should == 24
    Foo.simple_math.should == 2
  end

  it 'should correctly parse function signature' do
    module Foo
      inline <<-code
      void* func_1(void* ptr, unsigned int i, unsigned long l, char *c)
      {
          return ptr;
      }
      code
    end

    ptr = FFI::MemoryPointer.new(:int)
    Foo.func_1(ptr, 0xff, 0xffff, FFI::MemoryPointer.from_string('c')).should == ptr
  end

  it 'should load cached libraries' do

    File.should_receive(:read).once.and_return("\'dummy\'")

    module Foo
      inline "void* cached_func() {}"
    end

    module Foo
      inline "void* cached_func() {}"
    end

  end

  it 'should recompile if the code is updated' do

    module Foo
      inline "int updated_func() { return 1 + 1; }"
    end

    Foo.updated_func.should == 2

    module Foo
      inline "int updated_func() { return 2 + 2; }"
    end

    Foo.updated_func.should == 4

  end

  it 'should recompile if the code is changed after a failure' do
    # unfortunately this doesn't check the real functionality, which is that if a dll is deleted, it isn't re-produced
    begin
      module Foo
        inline "int updated_func2() { asdf }"
      end
    rescue
      begin
        Foo.updated_func2
        raise 'should have failed'
      rescue NoMethodError
      end
    end
    
    module Foo
      inline "int updated_func2() { return 2 + 2; }"
    end
    
    Foo.updated_func2.should == 4
  end

  it 'should be configured using the block form' do
    module Foo
      inline do |builder|
        builder.c %q{
          int func_1() 
          { 
            return 0; 
          };
        }
        builder.c %q{
          int func_2()
          { 
            return 1; 
          };
        }
      end
    end
    Foo.func_1.should == 0
    Foo.func_2.should == 1
  end
  
  it 'should allow users to add type maps' do
    class MyStruct < FFI::Struct
      layout :dummy, :int
    end
    module Foo
      inline do |builder|
        builder.map 'my_struct_t *' => 'pointer'
        builder.c_raw %q{
          typedef struct {
            int dummy;
          } my_struct_t;
        }
        builder.c 'my_struct_t* use_my_struct(my_struct_t *my_struct) { return my_struct; }'
      end
    end
    my_struct = MyStruct.new
    Foo.use_my_struct(my_struct).should == my_struct.to_ptr
  end

  it 'should allow users to include header files' do
    module Foo
      inline do |builder|
        builder.include "stdio.h"
        builder.include "local_header.h", :quoted => true
        builder.code.should == "#include <stdio.h>\n#include \"local_header.h\"\n"
        builder.stub!(:build)
      end
    end
  end

  it 'should allow users to add external libraries' do
    module Foo
      inline do |builder|
        builder.libraries 'foolib1', 'foolib2'
        builder.stub!(:build)
        builder.libraries.should == ['foolib1', 'foolib2']
      end
      inline "int func() { return 0; }", :libraries => ['foolib1', 'foolib2'] do |builder|
        builder.stub!(:build)
        builder.libraries.should == ['foolib1', 'foolib2']
      end
    end
  end
  
  if  RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
    it "should put library links at the end in mingw" do
      module Foo

        code = <<-CODE
        #include <windows.h>
            #include <mmsystem.h>
            int go() {
              mixerOpen(0, 0,0,0,0);
              return 3;
            }
        CODE
      
        inline do |builder|
          builder.library 'Winmm'
          builder.c_raw code
        end
        inline do |builder|
          builder.use_compiler Inliner::Compilers::GPlusPlus
          builder.library 'Winmm'
          builder.c_raw code
        end
      end
      
    end
  end

  it 'should generate C struct from FFI::Struct' do
    pending do
      class MyStruct < FFI::Struct
        layout :a, :int, \
        :b, :char, 
        :c, :pointer
      end
      module Foo
        extend Inliner
        inline do |builder|
          builder.struct MyStruct
          builder.code.should == <<EOC
typedef struct
{
int a;
char b;
void* c;
} my_struct_t;

EOC
        end
      end
    end
  end

  # FIXME: Eventually, find a better way to spec this
  #
  # it 'should use different compiler as specified in the configuration block' do
  #   module Foo
  #     inline do |builder|
  #       builder.use_compiler Inliner::Compilers::TCC
  #       builder.c "int func_1() { return 1 + 1; }"
  #     end
  #   end
  #   Foo.func_1.should == 2
  # end

  it 'should return the current compiler' do
    module Foo
      inline do |builder|
        builder.compiler.should == Inliner::Compilers::GCC
      end
    end
  end

  #   it 'should be configured using the hash form' do
  #     tcc = mock('tcc', :exists? => true, :compile => nil)
  #     Inliner::Compilers::TCC.should_receive(:new).and_return(tcc)
  #     module Foo
  #       inline "int func_1() { return 1; }", :compiler => Inliner::Compilers::TCC
  #     end
  #   end

  it 'should raise errors' do
    lambda {
      module Foo
        inline "int boom("
      end
    }.should raise_error(/Can\'t parse/)
    lambda {
      module Foo
        inline "int boom() { printf \"Hello\" }"
      end
    }.should raise_error(/Compile error/)
  end

  describe 'Compiler' do
    before do
      class DummyCC < Inliner::Compilers::Compiler
        def cmd
          "dummycc -shared"
        end
      end
    end
    it 'should return the progname' do
      DummyCC.new.progname.should == 'dummycc'
    end
  end

  describe 'GPlusPlus compiler' do
    
    it 'should compile and link a shim C library that encapsulates C++ code' do
      module Foo
        inline do |builder|
          builder.use_compiler Inliner::Compilers::GPlusPlus
          builder.c_raw <<-code
            #include <iostream>
            #include <string>
            using namespace std;
            class Greeter  {
                public:
                Greeter();
                string say_hello();
              };
              Greeter::Greeter() { };
              string Greeter::say_hello() {
                return "Hello foos!";
              };
              code
              builder.map 'char *' => 'string'
              builder.c <<-code
              const char* say_hello()
              { 
                Greeter greeter;
                return greeter.say_hello().c_str();
              }
            code
        end
      end
      Foo.say_hello.should == 'Hello foos!'
    end

  end

end

