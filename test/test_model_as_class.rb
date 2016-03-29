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

    describe "#name" do
        attr_reader :klass

        before do
            @klass = Class.new do
                extend MetaRuby::ModelAsClass
            end
        end

        after do
            if DefinitionContext.const_defined?(:Test)
                DefinitionContext.send(:remove_const, :Test)
            end
        end

        it "returns the default name for the class" do
            DefinitionContext.const_set(:Test, klass)
            assert_equal 'DefinitionContext::Test', DefinitionContext::Test.name
        end

        it "allows to override the class name" do
            DefinitionContext.const_set(:Test, klass)
            DefinitionContext::Test.name = "Test"
            assert_equal 'Test', DefinitionContext::Test.name
        end

        it "behaves identically for an anonymous submodel of a parent model" do
            parent = Class.new { extend MetaRuby::ModelAsClass }
            parent.name = "Parent"
            child = parent.new_submodel
            assert !child.name
            DefinitionContext.const_set(:Test, child)
            assert_equal 'DefinitionContext::Test', child.name
            child.name = "Test"
            assert_equal "Test", child.name
        end
        it "allows setting the name in #new_submodel" do
            parent = Class.new { extend MetaRuby::ModelAsClass }
            parent.name = "Parent"
            child = parent.new_submodel(name: 'Child')
            assert_equal 'Child', child.name
        end
        it "does not set the name if the name argument is not given" do
            meta = Module.new do
                include MetaRuby::ModelAsClass
                def setup_submodel(submodel, **options)
                    super
                    submodel.name = 'Test'
                end
            end
            parent = Class.new { extend meta }
            child = parent.new_submodel
            assert_equal 'Test', child.name
        end
    end
end
