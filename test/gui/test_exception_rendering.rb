require "metaruby/test"
require "metaruby/gui/exception_rendering"

module MetaRuby
    module GUI
        describe ExceptionRendering do
            describe "parse_backtrace" do
                it "handles nil backtraces" do
                    assert_equal [], ExceptionRendering.parse_backtrace(nil)
                end

                it "separates the file, line number and method part of the backtrace lines" do
                    backtrace = [
                        "a/file.rb:10:in `method`",
                        "b/file.rb:20:in `another method`"
                    ]
                    parsed = ExceptionRendering.parse_backtrace(backtrace)
                    expected = [["a/file.rb", 10, "in `method`"],
                                ["b/file.rb", 20, "in `another method`"]]
                    assert_equal expected, parsed
                end
            end

            describe "#parse_and_filter_backtrace" do
                subject { ExceptionRendering.new(flexmock) }

                let(:full_raw) do
                    ["a/file.rb:10:in `method`",
                     "b/file.rb:20:in `another method`"]
                end
                let(:full_parsed) do
                    [["a/file.rb", 10, "in `method`"],
                     ["b/file.rb", 20, "in `another method`"]]
                end

                it "returns empty for nil backtraces" do
                    assert_equal [[], []], subject.parse_and_filter_backtrace(nil)
                end
                it "passes both the raw and filtered versions of the backtrace to the filter" do
                    flexmock(subject).should_receive(:filter_backtrace).with(full_parsed,
                                                                             full_raw).once
                                     .and_return([])
                    subject.parse_and_filter_backtrace(full_raw)
                end
                it "parses the value returned by the backtrace filter if it is not already" do
                    flexmock(subject).should_receive(:filter_backtrace).with(full_parsed,
                                                                             full_raw).once
                                     .and_return(["c/file.rb:30:in `yet another method`"])
                    assert_equal [full_parsed, [["c/file.rb", 30, "in `yet another method`"]]],
                                 subject.parse_and_filter_backtrace(full_raw)
                end
                it "leaves the value returned by the backtrace filter alone if it is already parsed" do
                    flexmock(subject).should_receive(:filter_backtrace).with(full_parsed,
                                                                             full_raw).once
                                     .and_return([["c/file.rb", 30,
                                                   "in `yet another method`"]])
                    assert_equal [full_parsed, [["c/file.rb", 30, "in `yet another method`"]]],
                                 subject.parse_and_filter_backtrace(full_raw)
                end
            end
        end
    end
end
