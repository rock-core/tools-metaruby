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
end

