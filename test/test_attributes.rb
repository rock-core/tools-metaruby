require 'metaruby/test'

class TC_Models < MiniTest::Test
    def test_inherited_attribute_class
	a = Class.new do
            class << self
                extend MetaRuby::Attributes
                inherited_attribute(:signature, :signatures) { Array.new }
                inherited_attribute(:mapped, :map, :map => true) { Hash.new }
            end
	end
	b = Class.new(a) do
	    include Module.new # include an empty module between a and b to check that the module
			       # is skipped transparently
	    singleton_class.inherited_attribute(:child_attribute) { Array.new }
	end
	check_inherited_attribute(a, b)
	
	# Test for singleton class support
	object = b.new
	assert(object.singleton_class.respond_to?(:signatures))
	object.singleton_class.signatures << :in_singleton
	assert_equal([:in_singleton], object.singleton_class.signatures)
    end

    def check_inherited_attribute(base, derived)
	assert(base.respond_to?(:each_signature))
	assert(base.respond_to?(:signatures))
	assert(!base.respond_to?(:has_signature?))
	assert(!base.respond_to?(:find_signatures))

	assert(base.respond_to?(:each_mapped))
	assert(base.respond_to?(:map))
	assert(base.respond_to?(:has_mapped?))

        base.signatures << :in_base
        base.map[:base] = 10
        base.map[:overriden] = 20
        assert_equal([:in_base], base.enum_for(:each_signature).to_a)
        assert_equal([10].to_set, base.enum_for(:each_mapped, :base, false).to_set)

	assert(!base.respond_to?(:child_attribute))
	assert(!base.respond_to?(:each_child_attribute))
	assert(derived.respond_to?(:child_attribute))
	assert(derived.respond_to?(:each_child_attribute))

        derived.signatures << :in_derived

        derived.map[:overriden] = 15
        derived.map[:derived] = 25

        assert_equal([:in_derived, :in_base], derived.enum_for(:each_signature).to_a)
        assert_equal([20, 15].to_set, derived.enum_for(:each_mapped, :overriden, false).to_set)
        assert_equal([15].to_set, derived.enum_for(:each_mapped, :overriden, true).to_set)
        assert_equal([25].to_set, derived.enum_for(:each_mapped, :derived).to_set)
        assert_equal([[:base, 10], [:overriden, 20], [:overriden, 15], [:derived, 25]].to_set, derived.enum_for(:each_mapped, nil, false).to_set)
        assert_equal([[:base, 10], [:overriden, 15], [:derived, 25]].to_set, derived.enum_for(:each_mapped, nil, true).to_set)
    end

    def test_inherited_attribute_non_mapping_promote
	a = Class.new do
            class << self
                extend MetaRuby::Attributes
                def promote_value(v)
                    v
                end
                inherited_attribute(:value, :values) { Array.new }
            end
	end
        b = flexmock(Class.new(a), 'b')
        c = flexmock(Class.new(b), 'c')
        d = flexmock(Class.new(c), 'd')

        c.should_receive(:promote_value).with(10).and_return("10_b_c").once.ordered
        d.should_receive(:promote_value).with("10_b_c").and_return(12).once.ordered
        c.should_receive(:promote_value).with(11).and_return("11_b_c").once.ordered
        d.should_receive(:promote_value).with("11_b_c").and_return(13).once.ordered
        b.should_receive(:promote_value).with(0).and_return("0_b_c").once.ordered
        c.should_receive(:promote_value).with("0_b_c").and_return("0_c_d").once.ordered
        d.should_receive(:promote_value).with("0_c_d").and_return(2).once.ordered
        b.should_receive(:promote_value).with(1).and_return("1_b_c").once.ordered
        c.should_receive(:promote_value).with("1_b_c").and_return("1_c_d").once.ordered
        d.should_receive(:promote_value).with("1_c_d").and_return(3).once.ordered

        a.values << 0 << 1
        b.values << 10 << 11
        # Do NOT add anything at the level of C. Its promote_value method should
        # still be called, though
        d.values << 100 << 110
        assert_equal [0, 1], a.each_value.to_a
        assert_equal [100, 110, 12, 13, 2, 3], d.each_value.to_a
    end

    def test_inherited_attribute_mapping_promote
	a = Class.new do
            class << self
                extend MetaRuby::Attributes
                def promote_value(key, v)
                end
                def name; 'A' end
                inherited_attribute(:value, :values, :map => true) { Hash.new }
            end
	end
        b = Class.new(a)
        c = Class.new(b)
        d = Class.new(c)

        flexmock(c).should_receive(:promote_value).with('b', 2).and_return("b2_b_c").once.ordered
        flexmock(d).should_receive(:promote_value).with('b', "b2_b_c").and_return(15).once.ordered

        flexmock(c).should_receive(:promote_value).with('c', 3).and_return("c3_b_c").once.ordered
        flexmock(d).should_receive(:promote_value).with('c', "c3_b_c").and_return(16).once.ordered

        flexmock(b).should_receive(:promote_value).with('a', 0).and_return("a0_a_b").once.ordered
        flexmock(c).should_receive(:promote_value).with('a', "a0_a_b").and_return("a0_b_c").once.ordered
        flexmock(d).should_receive(:promote_value).with('a', "a0_b_c").and_return(10).once.ordered

        a.values.merge!('a' => 0, 'b' => 1)
        b.values.merge!('b' => 2, 'c' => 3, 'd' => 4)
        d.values.merge!('d' => 5, 'e' => 6)
        assert_equal [['d', 5], ['e', 6], ['b', 15], ['c', 16], ['a', 10]], d.each_value.to_a
    end

    def test_inherited_attribute_mapping_promote_non_uniq
	a = Class.new do
            class << self
                extend MetaRuby::Attributes
                def promote_value(key, v)
                end
                inherited_attribute(:value, :values, :map => true) { Hash.new }
            end
	end
        b = flexmock(Class.new(a), 'b')
        c = flexmock(Class.new(b), 'c')
        d = flexmock(Class.new(c), 'd')

        c.should_receive(:promote_value).with('b', 2).and_return("b2_b_c").once.ordered
        d.should_receive(:promote_value).with('b', "b2_b_c").and_return(12).once.ordered

        c.should_receive(:promote_value).with('c', 3).and_return("c3_b_c").once.ordered
        d.should_receive(:promote_value).with('c', "c3_b_c").and_return(13).once.ordered

        c.should_receive(:promote_value).with('d', 4).and_return("d4_b_c").once.ordered
        d.should_receive(:promote_value).with('d', "d4_b_c").and_return(14).once.ordered

        b.should_receive(:promote_value).with('a', 0).and_return("a0_a_b").once.ordered
        c.should_receive(:promote_value).with('a', "a0_a_b").and_return("a0_b_c").once.ordered
        d.should_receive(:promote_value).with('a', "a0_b_c").and_return(10).once.ordered

        b.should_receive(:promote_value).with('b', 1).and_return("b1_a_b").once.ordered
        c.should_receive(:promote_value).with('b', "b1_a_b").and_return("b1_b_c").once.ordered
        d.should_receive(:promote_value).with('b', "b1_b_c").and_return(11).once.ordered

        a.values.merge!('a' => 0, 'b' => 1)
        b.values.merge!('b' => 2, 'c' => 3, 'd' => 4)
        d.values.merge!('d' => 5, 'e' => 6)
        assert_equal [['d', 5], ['e', 6], ['b', 12], ['c', 13], ['d', 14], ['a', 10], ['b', 11]], d.each_value(nil, false).to_a
    end

    def test_inherited_attribute_mapping_promote_with_key_uniq
	a = Class.new do
            class << self
                extend MetaRuby::Attributes
                def promote_value(key, v)
                end
                inherited_attribute(:value, :values, :map => true) { Hash.new }
            end
	end
        b = flexmock(Class.new(a), 'b')
        c = flexmock(Class.new(b), 'c')
        d = flexmock(Class.new(c), 'd')

        c.should_receive(:promote_value).with('b', 2).and_return("b2_b_c").once.ordered
        d.should_receive(:promote_value).with('b', "b2_b_c").and_return(12).once.ordered

        a.values.merge!('a' => 0, 'b' => 1)
        b.values.merge!('b' => 2, 'c' => 3, 'd' => 4)
        d.values.merge!('d' => 5, 'e' => 6)
        assert_equal [12], d.each_value('b', true).to_a
    end

    def test_inherited_attribute_mapping_promote_with_key_non_uniq
	a = Class.new do
            class << self
                extend MetaRuby::Attributes
                def promote_value(key, v)
                end
                inherited_attribute(:value, :values, :map => true) { Hash.new }
            end
	end
        b = flexmock(Class.new(a), 'b')
        c = flexmock(Class.new(b), 'c')
        d = flexmock(Class.new(c), 'd')

        c.should_receive(:promote_value).with('b', 2).and_return("b2_b_c").once.ordered
        d.should_receive(:promote_value).with('b', "b2_b_c").and_return(12).once.ordered

        b.should_receive(:promote_value).with('b', 1).and_return("b1_a_b").once.ordered
        c.should_receive(:promote_value).with('b', "b1_a_b").and_return("b1_b_c").once.ordered
        d.should_receive(:promote_value).with('b', "b1_b_c").and_return(11).once.ordered

        a.values.merge!('a' => 0, 'b' => 1)
        b.values.merge!('b' => 2, 'c' => 3, 'd' => 4)
        d.values.merge!('d' => 5, 'e' => 6)
        assert_equal [12, 11], d.each_value('b', false).to_a
    end
end

describe MetaRuby::Attributes do
    describe "#inherited_single_value_attribute" do
        attr_reader :base, :sub, :subsub
        describe "plain" do
            before do
                @base = Class.new do
                    class << self
                        extend MetaRuby::Attributes
                        inherited_single_value_attribute :var
                    end
                end
                @sub = Class.new(base)
                @subsub = Class.new(sub)
            end

            it "should set the value if given an argument" do
                base.var(10)
                assert_equal 10, base.var
            end
            it "should return the value from the parent model if not set" do
                base.var(10)
                assert_equal 10, sub.var
            end
            it "should return nil if the instance variable is explicitly set to nil" do
                base.var 10
                sub.var nil
                assert_equal nil, subsub.var
            end
        end

        describe "with default" do
            before do
                @base = Class.new do
                    class << self
                        extend MetaRuby::Attributes
                        inherited_single_value_attribute(:var) { 10 }
                    end
                end
                @sub = Class.new(base)
                @subsub = Class.new(sub)
            end

            it "should be accessible at each level" do
                assert_equal 10, base.var
                assert_equal 10, sub.var
                assert_equal 10, subsub.var
            end

            it "should set only the bottom class" do
                assert_equal 10, base.var
                sub.var(nil)
                assert_equal nil, sub.var
                assert_equal nil, subsub.var
            end
        end

        describe "with promotion" do
            before do
                @base = Class.new do
                    class << self
                        extend MetaRuby::Attributes
                        def promote_var(value); value * 2 end
                        inherited_single_value_attribute(:var)
                    end
                end
                @sub = Class.new(base) do
                    class << self
                        def promote_var(value); value * 4 end
                    end
                end
                @subsub = Class.new(sub) do
                    class << self
                        def promote_var(value); value - 10 end
                    end
                end
            end

            it "should apply the promotion method at each level" do
                base.var(10)
                assert_equal 10, base.var
                assert_equal 40, sub.var
                assert_equal 30, subsub.var
            end
        end

        describe "with default with promotion" do
            before do
                @base = Class.new do
                    class << self
                        extend MetaRuby::Attributes
                        def promote_var(value); value * 2 end
                        inherited_single_value_attribute(:var) { 10 }
                    end
                end
                @sub = Class.new(base) do
                    class << self
                        def promote_var(value); value * 4 end
                    end
                end
                @subsub = Class.new(sub) do
                    class << self
                        def promote_var(value); value - 10 end
                    end
                end
            end

            it "should apply the promotion method at each level" do
                assert_equal 10, base.var
                assert_equal 40, sub.var
                assert_equal 30, subsub.var
            end
        end
    end
end

