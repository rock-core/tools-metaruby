require "utilrb/object/attribute"
require "weakref"

require "metaruby/backward/singleton_class_p"

require "metaruby/attributes"
require "metaruby/registration"
require "metaruby/model_as_module"
require "metaruby/model_as_class"

require "utilrb/logger"

# The toplevel namespace for MetaRuby
#
# MetaRuby is an implementation of a (very small) modelling toolkit that uses
# the Ruby type system as its meta-metamodel
module MetaRuby
    # Path to the metaruby.rb file (i.e. the root of the MetaRuby library)
    #
    # This is used to find ressources (css, javascript) that is bundled in the
    # metaruby repository
    LIB_DIR = File.expand_path("metaruby", File.dirname(__FILE__))

    extend Logger::Root("MetaRuby", Logger::WARN)

    class << self
        attr_predicate :keep_definition_location?, true
    end
    self.keep_definition_location = true
end
