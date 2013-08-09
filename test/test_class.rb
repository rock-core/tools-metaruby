require 'metaruby/test'

describe MetaRuby::ModelAsClass do
    include MetaRuby::SelfTest

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

    describe "#new_submodel" do
        it "should call setup_submodel only once" do
            mod = Module.new { include MetaRuby::ModelAsClass }
            klass = Class.new { extend mod }
            flexmock(klass).should_receive(:setup_submodel).once
            klass.new_submodel
        end
    end
end
