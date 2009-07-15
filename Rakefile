# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  begin
    load 'tasks/setup.rb'
  rescue LoadError
    raise RuntimeError, '### please install the "bones" gem ###'
  end
end

CLOBBER << '*~' << '*.*~'

PROJ.name = 'ffi-inliner'
PROJ.authors = 'Andrea Fazzi'
PROJ.email = 'andrea.fazzi@alcacoop.it'
PROJ.url = 'http://github.com/remogatto/ffi-inliner'
PROJ.version = '0.1.0'

PROJ.readme_file = 'README.rdoc'

PROJ.ann.paragraphs << 'FEATURES' << 'SYNOPSIS' << 'REQUIREMENTS' << 'DOWNLOAD/INSTALL' << 'CREDITS'
PROJ.ann.email[:from] = 'andrea.fazzi@alcacoop.it'
PROJ.ann.email[:to] << 'dev@ruby-ffi.kenai.com' << 'users@ruby-ffi.kenai.com'
PROJ.ann.email[:server] = 'smtp.gmail.com'

PROJ.spec.opts << '--color' << '-fs'

depend_on 'ffi', '0.4.0'
depend_on 'ffi-tcc'

task :default => 'spec'

# EOF
