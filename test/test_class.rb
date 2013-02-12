require 'metaruby'
require 'minitest/spec'
## flexmock is the mocking framework we advise you to use
# require 'flexmock/test_unit'

describe MetaRuby::ModelAsClass do
    before do
        # Code that is run before each test
    end
    after do
        # Code that is run after each test
    end

    describe "Using modules as metamodel" do
        it "should apply the Attribute module on sub-metamodels for classes" do
            mod = Module.new { include MetaRuby::ModelAsClass }
            sub = Module.new { include mod }
            assert mod.respond_to?(:inherited_attribute)
            assert sub.respond_to?(:inherited_attribute)
        end
    end
end
