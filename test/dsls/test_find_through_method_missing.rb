require 'metaruby/test'
require 'metaruby/dsls/find_through_method_missing'

module MetaRuby
    module DSLs
        describe FindThroughMethodMissing do
            describe "used on modules" do
                it "supports the model-as-class scheme" do
                    model = Module.new do
                        def find_event(e); end
                        MetaRuby::DSLs.setup_find_through_method_missing self, event: 'find_event'
                    end
                    k = Class.new do
                        extend model
                    end

                    flexmock(k).should_receive(:find_event).with('named').and_return(ret = flexmock)
                    assert_equal ret, k.named_event
                end
                it "setup done on module propagates to the classes the module is included in" do
                    m = Module.new do
                        def find_event(e); end
                        MetaRuby::DSLs.setup_find_through_method_missing self, event: 'find_event'
                    end
                    k = Class.new do
                        include m
                    end

                    obj = k.new
                    flexmock(obj).should_receive(:find_event).with('named').and_return(ret = flexmock)
                    assert_equal ret, obj.named_event
                end
            end

            describe "setup_find_through_method_missing" do
                it "registers the given mapping" do
                    klass = Class.new { def find_event; end }
                    DSLs.setup_find_through_method_missing klass, event: 'find_event'
                    assert_equal Hash['event' => :find_event], klass.metaruby_find_through_method_missing_suffixes
                end

                it "raises if the method does not exist" do
                    klass = Class.new
                    e = assert_raises(ArgumentError) do
                        DSLs.setup_find_through_method_missing klass, event: 'find_event'
                    end
                    assert_equal "find method 'find_event' listed for 'event' does not exist", e.message
                end
            end

            describe "find_through_method_missing_all_suffixes" do
                it "returns a regular expression to match the call name and a suffix-to-method mapping" do
                    base  = Class.new { def find_event(name); end }
                    DSLs.setup_find_through_method_missing base, event: 'find_event'
                    
                    matcher, suffix_to_method =
                        base.metaruby_find_through_method_missing_all_suffixes
                    assert_equal "(?-mix:_event$)", matcher.to_s
                    assert_equal Hash['_event' => :find_event],
                        suffix_to_method
                end

                describe "behaviour in subclasses" do
                    before do
                        @base  = Class.new { def find_event(name); end }
                        @child = Class.new(@base) { def find_port(name); end }
                        DSLs.setup_find_through_method_missing @base, event: 'find_event'
                        DSLs.setup_find_through_method_missing @child, port: 'find_port'
                    end

                    it "consolidates all suffixes in the hierarchy" do
                        matcher, suffix_to_method =
                            @child.metaruby_find_through_method_missing_all_suffixes
                        assert_equal "(?-mix:_port$|_event$)", matcher.to_s
                        assert_equal Hash['_event' => :find_event, '_port' => :find_port],
                            suffix_to_method
                    end
                    it "is not affecting base classes when adding suffixes to child classes" do
                        matcher, suffix_to_method =
                            @base.metaruby_find_through_method_missing_all_suffixes
                        assert_equal "(?-mix:_event$)", matcher.to_s
                        assert_equal Hash['_event' => :find_event],
                            suffix_to_method
                    end
                end
            end

            describe "#find_through_method_missing" do
                before do
                    klass = Class.new do
                        def find_test(obj); end
                        DSLs.setup_find_through_method_missing self, suffix: 'find_test'
                    end
                    @obj = klass.new
                end

                describe "call: true" do
                    it "returns nil if the method does not match a suffix" do
                        assert_nil @obj.find_through_method_missing("something_else", [], call: true)
                    end
                    it "calls the find_* method matching the suffix and returns the value" do
                        flexmock(@obj).should_receive(:find_test).with('obj').once.and_return(v = flexmock)
                        assert_equal v, @obj.find_through_method_missing("obj_suffix", [], call: true)
                    end

                    it "raises NoMethodError if the find method returns nil" do
                        flexmock(@obj).should_receive(:find_test).with('obj').once.and_return(nil)
                        e = assert_raises(NoMethodError) do
                            @obj.find_through_method_missing("obj_suffix", [], call: true)
                        end
                        assert_equal "#{@obj} has no suffix named obj", e.message
                    end

                    it "raises ArgumentError if the suffix matches and there are arguments" do
                        assert_raises(ArgumentError) do
                            @obj.find_through_method_missing("obj_suffix", [10], call: true)
                        end
                    end
                end

                describe "call: false" do
                    it "returns nil if the method does not match a suffix" do
                        assert_nil @obj.find_through_method_missing("something_else", [], call: false)
                    end
                    it "calls the find_* method matching the suffix and returns the value" do
                        flexmock(@obj).should_receive(:find_test).with('obj').once.and_return(v = flexmock)
                        assert_equal v, @obj.find_through_method_missing("obj_suffix", [], call: false)
                    end

                    it "returns nil if the find method returns nil" do
                        flexmock(@obj).should_receive(:find_test).with('obj').once.and_return(nil)
                        assert_nil @obj.find_through_method_missing("obj_suffix", [], call: false)
                    end

                    it "raises ArgumentError if the suffix matches and there are arguments" do
                        assert_raises(ArgumentError) do
                            @obj.find_through_method_missing("obj_suffix", [10], call: false)
                        end
                    end
                end
            end
        end

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
