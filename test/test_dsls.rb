require 'metaruby/test'
require 'metaruby/dsls/find_through_method_missing'

describe MetaRuby::DSLs do
    include MetaRuby::SelfTest

    describe "#find_through_method_missing" do
        it "should call the corresponding find method when matching" do
            obj = flexmock
            obj.should_receive(:find_obj).with("test").once.and_return(found = flexmock)
            assert_equal found, MetaRuby::DSLs.find_through_method_missing(obj, :test_obj, [], "obj")
        end
        it "should allow specifying the find method name" do
            obj = flexmock
            obj.should_receive(:find_obj).with("test").once.and_return(found = flexmock)
            assert_equal found, MetaRuby::DSLs.find_through_method_missing(obj, :test_bla, [], "bla" => 'find_obj')
        end
        it "should raise NoMethodError if the requested object is not found" do
            obj = flexmock
            obj.should_receive(:find_obj).with("test").once.and_return(nil)
            assert_raises(NoMethodError) do
                MetaRuby::DSLs.find_through_method_missing(obj, :test_obj, [], "obj")
            end
        end
        it "should raise ArgumentError if some arguments are given regardless of whether the object exists" do
            obj = flexmock
            obj.should_receive(:find_obj).never
            assert_raises(ArgumentError) do
                MetaRuby::DSLs.find_through_method_missing(obj, :test_obj, [10], "obj")
            end
        end
        it "should ignore non-matching methods and return nil" do
            obj = flexmock
            assert !MetaRuby::DSLs.find_through_method_missing(obj, :test_bla, [10], "obj")
        end
        it "should raise if the missing method is one of the expected find methods" do
            # NOTE: do not use flexmock here, as specifying 'never' on a call
            # spec makes flexmock raise a NoMethodError !!!
            called = false
            obj = Class.new do
                define_method(:find_obj) { |name| called = true }
            end.new
            assert_raises(NoMethodError) do
                MetaRuby::DSLs.find_through_method_missing(obj, :find_obj, [], "obj")
            end
            assert !called
        end
    end
end
