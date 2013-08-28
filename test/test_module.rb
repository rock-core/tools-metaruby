require 'metaruby/test'

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
        it "should mark the model as non-permanent" do
            root = Module.new do
                extend MetaRuby::ModelAsModule
                self.root = true
            end
            sub = root.new_submodel
            assert !sub.new_submodel.permanent_model?
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
            flexmock(MetaRuby::Registration).should_receive(:accessible_by_name?).with(definition_context).and_return(true)
            result = MetaRuby::ModelAsModule.create_and_register_submodel(definition_context, 'Test', base_m)
            assert result.permanent_model?
        end
        it "should set permanent_model to false if the enclosing module is a Ruby module that is not accessible by name" do
            flexmock(definition_context).should_receive(:accessible_by_name?).and_return(false)
            result = MetaRuby::ModelAsModule.create_and_register_submodel(definition_context, 'Test', base_m)
            assert !result.permanent_model?
        end
        it "should set permanent_model to true if the enclosing module is permanent" do
            flexmock(definition_context).should_receive(:permanent_model?).and_return(true)
            result = MetaRuby::ModelAsModule.create_and_register_submodel(definition_context, 'Test', base_m)
            assert result.permanent_model?
        end
        it "should set permanent_model to false if the enclosing module is non-permanent" do
            flexmock(definition_context).should_receive(:permanent_model?).and_return(false)
            result = MetaRuby::ModelAsModule.create_and_register_submodel(definition_context, 'Test', base_m)
            assert !result.permanent_model?
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
end

