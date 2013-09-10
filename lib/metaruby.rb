VERSION = "0.1.0"

require 'utilrb/object/attribute'

require 'metaruby/inherited_attribute'
require 'metaruby/registration'
require 'metaruby/module'
require 'metaruby/class'

# The toplevel namespace for MetaRuby
#
# MetaRuby is an implementation of a (very small) modelling toolkit that uses
# the Ruby type system as its meta-metamodel
require 'utilrb/logger'
module MetaRuby
    LIB_DIR = File.expand_path('metaruby', File.dirname(__FILE__))
    extend Logger::Root('MetaRuby', Logger::WARN)
end

