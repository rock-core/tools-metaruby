# frozen_string_literal: true

require "metaruby/test"

module MetaRuby
    module Attributes
        describe "map without cache" do
            describe "without promotion" do
                before do
                    model = Module.new do
                        extend Attributes

                        inherited_attribute(:attr) { [] }
                    end
                    @parent = Class.new do
                        extend model
                    end
                    @child = Class.new(@parent)
                    @leaf = Class.new(@child)
                end

                describe "each_NAME" do
                    it "enumerates the aggregated values" do
                        @parent.attr << 42
                        @child.attr << 21
                        @leaf.attr << 84
                        assert_equal [84, 21, 42], @leaf.each_attr.to_a
                        assert_equal [21, 42], @child.each_attr.to_a
                        assert_equal [42], @parent.each_attr.to_a
                    end

                    it "shows values that have been updated in the hierarchy" do
                        @parent.attr << 42
                        @child.attr << 21
                        @leaf.attr << 84
                        @leaf.each_attr.to_a

                        @parent.attr.replace([43])
                        @child.attr.replace([22])
                        @leaf.attr.replace([85])

                        assert_equal [85, 22, 43], @leaf.each_attr.to_a
                        assert_equal [22, 43], @child.each_attr.to_a
                        assert_equal [43], @parent.each_attr.to_a
                    end

                    it "stops showing values that have been removed" do
                        @parent.attr << 42
                        @child.attr << 21
                        @leaf.attr << 84
                        @leaf.each_attr.to_a

                        @parent.attr.clear

                        assert_equal [84, 21], @leaf.each_attr.to_a
                        assert_equal [21], @child.each_attr.to_a
                        assert_equal [], @parent.each_attr.to_a
                    end
                end
            end

            describe "with promotion" do
                before do
                    model = Module.new do
                        extend Attributes

                        def promote_attr(value)
                            value + 1
                        end

                        inherited_attribute(:attr) { [] }
                    end
                    @parent = Class.new do
                        extend model
                    end
                    @child = Class.new(@parent)
                    @leaf = Class.new(@child)
                end

                describe "each_NAME" do
                    it "enumerates the aggregated values" do
                        @parent.attr << 42
                        @child.attr << 21
                        @leaf.attr << 84
                        assert_equal [84, 22, 44], @leaf.each_attr.to_a
                        assert_equal [21, 43], @child.each_attr.to_a
                        assert_equal [42], @parent.each_attr.to_a
                    end

                    it "shows values that have been updated in the hierarchy" do
                        @parent.attr << 42
                        @child.attr << 21
                        @leaf.attr << 84
                        @leaf.each_attr.to_a

                        @parent.attr.replace([43])
                        @child.attr.replace([22])
                        @leaf.attr.replace([85])

                        assert_equal [85, 23, 45], @leaf.each_attr.to_a
                        assert_equal [22, 44], @child.each_attr.to_a
                        assert_equal [43], @parent.each_attr.to_a
                    end

                    it "stops showing values that have been removed" do
                        @parent.attr << 42
                        @child.attr << 21
                        @leaf.attr << 84
                        @leaf.each_attr.to_a

                        @parent.attr.clear

                        assert_equal [84, 22], @leaf.each_attr.to_a
                        assert_equal [21], @child.each_attr.to_a
                        assert_equal [], @parent.each_attr.to_a
                    end
                end
            end
        end
    end
end
