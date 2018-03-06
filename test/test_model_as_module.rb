require 'metaruby/test'

module ResolvableContext
end

describe MetaRuby::ModelAsModule do
    include MetaRuby::SelfTest

    attr_reader :root_m
    before do
        @root_m = Module.new { extend MetaRuby::ModelAsModule }
    end

    describe "#provides" do
        it "sets the supermodel to the provided model if it is root" do
            root_m.root = true
            submodel = Module.new { extend MetaRuby::ModelAsModule }
            submodel.provides root_m
            assert_equal root_m, submodel.supermodel
        end
        it "sets root_model to the provided model's supermodel if the provided model is not root itself" do
            flexmock(root_m).should_receive(:supermodel).once.
                and_return(root = flexmock)
            submodel = Module.new { extend MetaRuby::ModelAsModule }
            root.should_receive(:register_submodel).with(submodel).once
            submodel.provides root_m
            assert_equal root, submodel.supermodel
        end
        it "does not override a supermodel that is more specialized than the provided model's supermodel" do
            root = Module.new { extend MetaRuby::ModelAsModule }
            root.root = true
            root_model = root.new_submodel
            subroot = root.new_submodel
            subroot.root = true
            subroot_model = subroot.new_submodel
            subroot_model.provides root_model
            assert_equal subroot, subroot_model.supermodel
        end
        it "raises if the two supermodels are unrelated" do
            root = Module.new { extend MetaRuby::ModelAsModule }
            root.root = true
            root_model = root.new_submodel
            other_root = Module.new { extend MetaRuby::ModelAsModule }
            other_root.root = true
            other_root_model = other_root.new_submodel
            assert_raises(ArgumentError) do
                other_root_model.provides root_model
            end
        end
        it "updates #supermodel to the model's supermodel if the new supermodel provides the current one" do
            root = Module.new { extend MetaRuby::ModelAsModule }
            root.root = true
            subroot = root.new_submodel
            subroot.root = true
            subroot_model = subroot.new_submodel

            model = root.new_submodel
            model.provides subroot_model
            assert_same subroot, model.supermodel
        end
    end

    describe "Using modules as metamodel" do
        it "should apply the Attribute module on sub-metamodels for modules" do
            mod = Module.new { include MetaRuby::ModelAsModule }
            sub = Module.new { include mod }
            assert mod.respond_to?(:inherited_attribute)
            assert sub.respond_to?(:inherited_attribute)
        end
    end

    describe "#new_submodel" do
        it "marks the model as non-permanent" do
            root = Module.new do
                extend MetaRuby::ModelAsModule
                self.root = true
            end
            sub = root.new_submodel
            assert !sub.new_submodel.permanent_model?
        end

        it "makes its 'name' argument accessible to the setup_submodel method" do
            meta = Class.new(Module) do
                include MetaRuby::ModelAsModule
                attr_accessor :setup_name
                def setup_submodel(submodel, **options)
                    submodel.setup_name = submodel.name
                end
            end
            root = meta.new do
                self.root = true
            end
            submodel = root.new_submodel(name: 'test')
            assert_equal 'test', submodel.name
            assert_equal 'test', submodel.setup_name
        end
    end

    describe "#create_and_register_submodel" do
        attr_reader :definition_context, :base_m
        before do
            @definition_context = Module.new
            @base_m = Module.new do
                extend MetaRuby::ModelAsModule
                def self.root?; true end
            end
        end

        it "should set permanent_model to true if the enclosing module is a Ruby module that is accessible by name" do
            flexmock(MetaRuby::Registration).should_receive(:accessible_by_name?).once.with(definition_context).and_return(true)
            result = MetaRuby::ModelAsModule.create_and_register_submodel(definition_context, 'Test', base_m)
            assert result.permanent_model?
        end
        it "should set permanent_model to false if the enclosing module is a Ruby module that is not accessible by name" do
            flexmock(MetaRuby::Registration).should_receive(:accessible_by_name?).once.with(definition_context).and_return(false)
            result = MetaRuby::ModelAsModule.create_and_register_submodel(definition_context, 'Test', base_m)
            assert !result.permanent_model?
        end
        it "should set permanent_model to true if the enclosing module is permanent" do
            flexmock(definition_context).should_receive(:permanent_model?).explicitly.and_return(true)
            result = MetaRuby::ModelAsModule.create_and_register_submodel(definition_context, 'Test', base_m)
            assert result.permanent_model?
        end
        it "should set permanent_model to false if the enclosing module is non-permanent" do
            flexmock(definition_context).should_receive(:permanent_model?).explicitly.and_return(false)
            result = MetaRuby::ModelAsModule.create_and_register_submodel(definition_context, 'Test', base_m)
            assert !result.permanent_model?
        end
        it "calls setup_submodel on an already registered constant" do
            definition_context.const_set('Test', base_m.new_submodel)
            flexmock(base_m).should_receive(:setup_submodel).once.pass_thru
            MetaRuby::ModelAsModule.create_and_register_submodel(definition_context, 'Test', base_m)
        end
    end

    describe "#name" do
        attr_reader :base_m
        before do
            @base_m = Module.new do
                extend MetaRuby::ModelAsModule
                def self.root?; true end
            end
        end

        after do
            if ResolvableContext.const_defined?(:Base, false)
                ResolvableContext.send(:remove_const, :Base)
            end
            if ResolvableContext.const_defined?(:Test, false)
                ResolvableContext.send(:remove_const, :Test)
            end
        end

        it "is nil by default" do
            assert !base_m.name
            assert !base_m.new_submodel.name
        end

        it "is set to the module's default name if assigned to a resolvable constant" do
            ResolvableContext.const_set :Base, base_m
            ResolvableContext.const_set :Test, (test_m = base_m.new_submodel)
            assert_equal "ResolvableContext::Base", base_m.name
            assert_equal "ResolvableContext::Test", test_m.name
        end

        it "can be overriden" do
            ResolvableContext.const_set :Test, (test_m = base_m.new_submodel)
            test_m.name = "Override"
            assert_equal "Override", test_m.name
        end

        it "can be set in #new_submodel" do
            test_m = base_m.new_submodel(name: 'Override')
            ResolvableContext.const_set :Test, test_m
            assert_equal "Override", test_m.name
        end
    end

    describe "#clear_model" do
        attr_reader :root_m, :model_m
        before do
            @root_m = Module.new do
                extend MetaRuby::ModelAsModule
                self.root = true
                self.permanent_model = true
            end
            @model_m = root_m.new_submodel
            model_m.permanent_model = true
        end

        it "deregisters the module regardless of the permanent_model flag" do
            flexmock(root_m).should_receive(:deregister_submodels).with([model_m]).once
            model_m.permanent_model = true
            model_m.clear_model
        end
        it "clears its parent model set" do
            flexmock(root_m).should_receive(:deregister_submodels).with([model_m]).once
            model_m.permanent_model = true
            model_m.clear_model
            assert model_m.parent_models.empty?
        end
    end

    describe "#has_submodel?" do
        attr_reader :root_m
        before do
            @root_m = Module.new do
                extend MetaRuby::ModelAsModule
                self.root = true
            end
        end

        it "returns true if the receiver is the model's supermodel" do
            assert root_m.has_submodel?(root_m.new_submodel)
        end
        it "returns true if the receiver is the model's supermodel's supermodel" do
            subroot_m = root_m.new_submodel
            subroot_m.root = true
            m = subroot_m.new_submodel
            assert root_m.has_submodel?(m)
            assert subroot_m.has_submodel?(m)
        end
        it "returns false if the model is unrelated" do
            refute root_m.new_submodel.has_submodel?(root_m.new_submodel)
        end
        it "returns false if the receiver is provided but it is not one of the supermodels" do
            m = root_m.new_submodel
            m.provides(provided_m = root_m.new_submodel)
            refute provided_m.has_submodel?(m)
        end
        it "returns false for a model-as-class that provides the model-as-module" do
            klass = Class.new { extend MetaRuby::ModelAsClass }
            klass.provides(m = root_m.new_submodel)
            assert !m.has_submodel?(klass)
            assert !m.has_submodel?(klass.new_submodel)
        end
    end
end

