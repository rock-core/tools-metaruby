require 'metaruby/test'

class Base
    extend MetaRuby::ModelAsClass
end

module DefinitionContext
    class Klass < Base; end
end

module PermanentDefinitionContext
    def self.permanent_model?; true end
    class Klass < Base; end
end

module NonPermanentDefinitionContext
    def self.permanent_model?; false end
    class Klass < Base; end
end

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
        it "should set permanent_model to false on the class" do
        end
    end

    describe "creating subclasses" do
        it "should set permanent_model to false on the class if the enclosing context is not properly registered as a constant" do
            definition_context = Module.new do
                Klass = Class.new(Base)
            end
            assert !definition_context.const_get(:Klass).permanent_model?
        end
        it "should set permanent_model to true on the class if the enclosing context is properly registered as a constant but is not responding to permanent_model?" do
            assert DefinitionContext::Klass.permanent_model?
        end
        it "should set permanent_model to true on the class if the enclosing context is permanent" do
            assert PermanentDefinitionContext::Klass.permanent_model?
        end
        it "should set permanent_model to false on the class if the enclosing context is not permanent" do
            assert !NonPermanentDefinitionContext::Klass.permanent_model?
        end
    end
end
