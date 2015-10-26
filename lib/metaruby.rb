require 'utilrb/object/attribute'
require 'weakref'

require 'metaruby/inherited_attribute'
require 'metaruby/registration'
require 'metaruby/module'
require 'metaruby/class'

require 'utilrb/logger'

# The toplevel namespace for MetaRuby
#
# MetaRuby is an implementation of a (very small) modelling toolkit that uses
# the Ruby type system as its meta-metamodel
module MetaRuby
    # Path to the metaruby.rb file (i.e. the root of the MetaRuby library)
    #
    # This is used to find ressources (css, javascript) that is bundled in the
    # metaruby repository
    LIB_DIR = File.expand_path('metaruby', File.dirname(__FILE__))

    extend Logger::Root('MetaRuby', Logger::WARN)
end

