# frozen_string_literal: true

require "metaruby/test"
require_relative "common"

module MetaRuby
    module Attributes
        describe "map without cache" do
            it "allows to use a module before the inherited attribute gets " \
               "defined on it" do
                mod = Module.new
                root = Class.new do
                    extend ModelAsClass
                    extend mod
                end
                mod.class_eval do
                    extend Attributes
                    inherited_attribute(:attr, :attrs, map: true) { {} }
                end

                assert_equal({}, root.attrs)
                assert_equal [], root.each_attr.to_a
                assert_nil root.find_attr("foo")
            end

            describe "without promotion" do
                before do
                    model = Module.new do
                        extend Attributes

                        inherited_attribute(:attr, :attrs, map: true) { {} }
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

                it "defines the attribute method" do
                    assert_equal({}, @parent.attrs)
                end

                InheritedAttributes::Map.common_without_promotion(self, cache: false)
            end

            describe "with promotion" do
                before do
                    model = Module.new do
                        extend Attributes

                        def promote_attr(_key, value)
                            value + 1
                        end

                        inherited_attribute(:attr, :attrs, map: true) { {} }
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

                it "defines the attribute method" do
                    assert_equal({}, @parent.attrs)
                end

                InheritedAttributes::Map.common_with_promotion(self, cache: false)
            end
        end
    end
end
