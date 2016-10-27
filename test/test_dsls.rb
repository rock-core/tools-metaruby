require 'metaruby/test'
require 'metaruby/dsls/doc'
require 'metaruby/dsls/find_through_method_missing'

describe MetaRuby::DSLs do
    include MetaRuby::SelfTest

    describe '.parse_documentation_block' do
        it "returns the block just before the call to the matching method" do
            env = Class.new do
                def dsl_method; MetaRuby::DSLs.parse_documentation_block(/.*/, /dsl_/) end
                def calling_method; dsl_method end
            end.new
            flexmock(MetaRuby::DSLs).should_receive(:parse_documentation_block_at).
                with(__FILE__, __LINE__ - 3).once.and_return(block = flexmock)
            assert_equal block, env.calling_method
        end

        it "ignores method_missing calls between the dsl method and its caller" do
            env = Class.new do
                def dsl_method; MetaRuby::DSLs.parse_documentation_block(/.*/, /dsl_/) end
                def calling_method; dsl end
                def method_missing(m, *args)
                    if m == :dsl
                        dsl_method
                    else super
                    end
                end
            end.new
            flexmock(MetaRuby::DSLs).should_receive(:parse_documentation_block_at).
                with(__FILE__, __LINE__ - 9).once.and_return(block = flexmock)
            assert_equal block, env.calling_method
        end

        it "returns nil if the matched callsite is not a file" do
            env = Class.new do
                def dsl_method; MetaRuby::DSLs.parse_documentation_block(/.*/, /dsl_/) end
                def calling_method; dsl_method end
            end.new
            flexmock(File).should_receive(:file?).with(__FILE__).and_return(false)
            flexmock(File).should_receive(:file?).pass_thru
            flexmock(MetaRuby::DSLs).should_receive(:parse_documentation_block_at).never
            assert_nil env.calling_method
        end
    end

    describe ".parse_documentation_block_at" do
        it "returns the comment block just before the given file/line, with the comment part removed" do
            # This is the expected comment
            # Block
            assert_equal "This is the expected comment\nBlock", MetaRuby::DSLs.parse_documentation_block_at(__FILE__, __LINE__)
        end
        it "stops if there is an empty line" do
            # Block
            
            # This is the expected part
            assert_equal "This is the expected part", MetaRuby::DSLs.parse_documentation_block_at(__FILE__, __LINE__)
        end
        it "keeps formatting within the block" do
            # First line
            #   Indented second line
            #   Indented third line
            # Fourth line
            assert_equal "First line\n  Indented second line\n  Indented third line\nFourth line",
                MetaRuby::DSLs.parse_documentation_block_at(__FILE__, __LINE__ - 1)
        end
        it "ignores empty comment lines when removing leading spaces" do
            # First line
            #   Indented second line
            #   Indented third line
            #
            # Fourth line
            assert_equal "First line\n  Indented second line\n  Indented third line\n\nFourth line",
                MetaRuby::DSLs.parse_documentation_block_at(__FILE__, __LINE__ - 1)
        end

        it "considers formatting spaces only after the comment sign" do
            # First line
                #   Indented second line
                #   Indented third line
            #
            # Fourth line
            assert_equal "First line\n  Indented second line\n  Indented third line\n\nFourth line",
                MetaRuby::DSLs.parse_documentation_block_at(__FILE__, __LINE__ - 1)
        end
    end

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
