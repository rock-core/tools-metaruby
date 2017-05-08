require 'metaruby/test'
require 'metaruby/dsls/find_through_method_missing'

module MetaRuby
    module DSLs
        describe ".find_through_method_missing" do
            describe "call: true" do
                it "returns nil if the method does not match a suffix" do
                    obj = flexmock
                    assert_nil DSLs.find_through_method_missing(
                        obj, "something_else", [], "suffix" => "find_test", call: true)
                end
                it "calls the find_* method matching the suffix and returns the value" do
                    obj = flexmock
                    obj.should_receive(:find_test).with('obj').once.and_return(v = flexmock)
                    assert_equal v, DSLs.find_through_method_missing(
                        obj, "obj_suffix", [], "suffix" => "find_test", call: true)
                end

                it "raises NoMethodError if the find method returns nil" do
                    obj = flexmock
                    obj.should_receive(:find_test).with('obj').once.and_return(nil)
                    e = assert_raises(NoMethodError) do
                        DSLs.find_through_method_missing(
                            obj, "obj_suffix", [], "suffix" => "find_test", call: true)
                    end
                    assert_equal "#{obj} has no suffix named obj", e.message
                end

                it "raises ArgumentError if the suffix matches and there are arguments" do
                    obj = flexmock
                    assert_raises(ArgumentError) do
                        DSLs.find_through_method_missing(
                            obj, "obj_suffix", [10], "suffix" => "find_test", call: true)
                    end
                end
            end

            describe "call: false" do
                it "returns nil if the method does not match a suffix" do
                    obj = flexmock
                    assert_nil DSLs.find_through_method_missing(
                        obj, "something_else", [], "suffix" => "find_test", call: false)
                end
                it "calls the find_* method matching the suffix and returns the value" do
                    obj = flexmock
                    obj.should_receive(:find_test).with('obj').once.and_return(v = flexmock)
                    assert_equal v, DSLs.find_through_method_missing(
                        obj, "obj_suffix", [], "suffix" => "find_test", call: false)
                end

                it "returns nil if the find method returns nil" do
                    obj = flexmock
                    obj.should_receive(:find_test).with('obj').once.and_return(nil)
                    assert_nil DSLs.find_through_method_missing(
                        obj, "obj_suffix", [], "suffix" => "find_test", call: false)
                end

                it "raises ArgumentError if the suffix matches and there are arguments" do
                    obj = flexmock
                    assert_raises(ArgumentError) do
                        DSLs.find_through_method_missing(
                            obj, "obj_suffix", [10], "suffix" => "find_test", call: false)
                    end
                end
            end
        end
    end
end
