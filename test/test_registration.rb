require 'metaruby/test'

describe MetaRuby::Registration do
    include MetaRuby::SelfTest

    class ModelStub
        extend MetaRuby::Registration
    end

    def model_stub(parent_model = nil)
        result = Class.new(ModelStub)
        result.permanent_model = false
        flexmock(result).should_receive(:supermodel).and_return(parent_model).by_default
        if parent_model
            parent_model.register_submodel(result)
        end
        result
    end

    describe "#register_submodel" do
        attr_reader :base_model
        before do
            @base_model = model_stub
        end

        it "registers the model on the receiver" do
            sub_model = Class.new(ModelStub)
            base_model.register_submodel(sub_model)
            assert(base_model.each_submodel.find { |m| m == sub_model })
        end
        it "registers the model on the receiver's parent model" do
            parent_model = Class.new(ModelStub)
            sub_model = Class.new(ModelStub)
            flexmock(base_model).should_receive(:supermodel).and_return(parent_model)
            flexmock(parent_model).should_receive(:register_submodel).with(sub_model).once
            base_model.register_submodel(sub_model)
        end
    end

    describe "#deregister_submodel" do
        attr_reader :base_model, :sub_model
        before do
            @base_model = model_stub
            @sub_model = model_stub(base_model)
        end

        it "deregisters the models on the receiver" do
            flexmock(base_model).should_receive(:supermodel).and_return(nil).once
            base_model.deregister_submodels([sub_model])
            assert(base_model.each_submodel.to_a.empty?)
        end
        it "deregisters the models on the receiver's parent model" do
            parent_model = flexmock
            flexmock(base_model).should_receive(:supermodel).and_return(parent_model)
            flexmock(parent_model).should_receive(:deregister_submodels).with([sub_model]).once
            base_model.deregister_submodels([sub_model])
        end
        it "always calls the parent model's deregister method" do
            parent_model = flexmock
            flexmock(base_model).should_receive(:supermodel).and_return(parent_model)
            flexmock(base_model).should_receive(:deregister_submodels).with([sub_model]).pass_thru
            flexmock(parent_model).should_receive(:deregister_submodels).with([sub_model]).once
            base_model.deregister_submodels([sub_model])
        end
        it "returns true if a model got deregistered" do
            flexmock(base_model).should_receive(:supermodel).and_return(nil).once
            assert base_model.deregister_submodels([sub_model])
        end
        it "returns false if no models got deregistered" do
            assert !base_model.deregister_submodels([flexmock])
        end
    end

    describe "#clear_models" do
        attr_reader :base_model, :sub_model
        before do
            @base_model = model_stub
            @sub_model = model_stub(base_model)
        end
        it "deregisters the non-permanent models, and calls #clear_submodels on them" do
            base_model.should_receive(:deregister_submodels).with([sub_model]).once.pass_thru
            sub_model.should_receive(:clear_submodels).once
            base_model.clear_submodels
        end
        it "does not deregister the permanent models, but still calls #clear_submodels on them" do
            base_model.should_receive(:deregister_submodels).with([]).once
            sub_model.should_receive(:permanent_model?).and_return(true).once
            sub_model.should_receive(:clear_submodels).once
            base_model.clear_submodels
        end
        it "calls #clear_submodels on non-permanent submodels" do
            flexmock(sub_model).should_receive(:permanent_model?).and_return(false).once
            flexmock(sub_model).should_receive(:clear_submodels).once
            base_model.clear_submodels
        end
        it "calls #clear_submodels on permanent submodels" do
            flexmock(sub_model).should_receive(:permanent_model?).and_return(true).once
            flexmock(sub_model).should_receive(:clear_submodels).once
            # Create another submodel so that there is something to clear
            model_stub(base_model)
            base_model.clear_submodels
        end
        it "does not deregister the permanent models" do
            flexmock(sub_model).should_receive(:permanent_model?).and_return(true).once
            flexmock(base_model).should_receive(:deregister_submodels).with([]).once
            base_model.clear_submodels
        end
        it "should deregister before it clears" do
            flexmock(sub_model).should_receive(:permanent_model?).and_return(false).once
            flexmock(base_model).should_receive(:deregister_submodels).once.ordered.pass_thru
            flexmock(sub_model).should_receive(:clear_submodels).once.ordered
            base_model.clear_submodels
        end
    end
end

