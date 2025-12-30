# frozen_string_literal: true

require "metaruby/test"

module MetaRuby
    module Attributes
        describe "map without cache" do
            describe "without promotion" do
                before do
                    model = Module.new do
                        extend Attributes

                        inherited_single_value_attribute(:attr) { :default }
                    end
                    @parent = Class.new do
                        extend model
                    end
                    @child = Class.new(@parent)
                    @leaf = Class.new(@child)
                end

                it "returns the default if unset" do
                    assert_equal :default, @leaf.attr
                end

                it "returns a parent's value" do
                    @parent.attr(42)
                    assert_equal 42, @leaf.attr
                end

                it "returns the most derived value" do
                    @parent.attr(42)
                    @child.attr(21)
                    assert_equal 21, @leaf.attr
                end

                it "returns the most derived even if it is nil" do
                    @parent.attr(42)
                    @child.attr(nil)
                    assert_nil @leaf.attr
                end

                it "returns the value from self if set" do
                    @parent.attr(42)
                    @child.attr(21)
                    @leaf.attr(84)
                    assert_equal 84, @leaf.attr
                end

                it "does nothing on a value update that is not the most derived" do
                    @parent.attr(42)
                    @child.attr(21)
                    assert_equal 21, @leaf.attr

                    @parent.attr(0)
                    assert_equal 21, @leaf.attr
                end

                it "reflects updates to the most derived value" do
                    @parent.attr(42)
                    @child.attr(21)
                    assert_equal 21, @leaf.attr

                    @child.attr(0)
                    assert_equal 0, @leaf.attr
                end
            end

            describe "with promotion" do
                before do
                    model = Module.new do
                        extend Attributes

                        def promote_attr(value)
                            value + 1
                        end
                        inherited_single_value_attribute(:attr) { 10 }
                    end
                    @parent = Class.new do
                        extend model
                    end
                    @child = Class.new(@parent)
                    @leaf = Class.new(@child)
                end

                it "returns the default if unset" do
                    assert_equal 12, @leaf.attr
                end

                it "returns a promoted parent's value" do
                    @parent.attr(42)
                    assert_equal 44, @leaf.attr
                end

                it "returns the most derived value" do
                    @parent.attr(42)
                    @child.attr(21)
                    assert_equal 22, @leaf.attr
                end

                it "returns the value from self if set" do
                    @parent.attr(42)
                    @child.attr(21)
                    @leaf.attr(84)
                    assert_equal 84, @leaf.attr
                end

                it "does nothing on a value update that is not the most derived" do
                    @parent.attr(42)
                    @child.attr(21)
                    assert_equal 22, @leaf.attr

                    @parent.attr(0)
                    assert_equal 22, @leaf.attr
                end

                it "reflects updates to the most derived value" do
                    @parent.attr(42)
                    @child.attr(21)
                    assert_equal 22, @leaf.attr

                    @child.attr(0)
                    assert_equal 1, @leaf.attr
                end
            end
        end
    end
end
