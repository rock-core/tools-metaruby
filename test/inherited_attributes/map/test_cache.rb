# frozen_string_literal: true

require "metaruby/test"
require_relative "common"

module MetaRuby
    module Attributes
        describe "map with cache" do
            describe "without promotion" do
                before do
                    model = Module.new do
                        include ModelAsClass
                        extend Attributes

                        inherited_attribute(:attr, :attrs, map: true, cache: true) { {} }
                    end
                    root = Class.new do
                        extend ModelAsClass
                    end
                    @parent = Class.new(root) do
                        extend model
                    end
                    @child = Class.new(@parent)
                    @leaf = Class.new(@child)
                end

                InheritedAttributes::Map.common_without_promotion(self, cache: true)
            end

            describe "with promotion" do
                before do
                    model = Module.new do
                        include ModelAsClass
                        extend Attributes

                        def promote_attr(_key, value)
                            value + 1
                        end

                        inherited_attribute(:attr, :attrs, map: true, cache: true) { {} }
                    end
                    root = Class.new do
                        extend ModelAsClass
                    end
                    @parent = Class.new(root) do
                        extend model
                    end
                    @child = Class.new(@parent)
                    @leaf = Class.new(@child)
                end

                InheritedAttributes::Map.common_with_promotion(self, cache: true)
            end
        end
    end
end
