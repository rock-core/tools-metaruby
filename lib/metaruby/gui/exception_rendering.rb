module MetaRuby
    module GUI
        # Functionality to render exceptions in an HTML view
        #
        # On top of properly formatting the exception, it introduces backtrace
        # filtering and javascript-based buttons to enable backtraces on or off.
        class ExceptionRendering
            RESSOURCES_DIR = File.expand_path('html', File.dirname(__FILE__))

            # @return [#link_to] an object that allows to render a link to an
            #   object
            attr_reader :linker

            # @return [#[]] an object that can be used to determine whether a
            #   file is a user or framework file. It is used in backtrace
            #   filtering and rendering. The default returns true for any file.
            attr_reader :user_file_filter

            # Sets {#user_file_filter} or resets it to the default
            #
            # @param [nil,#[]] filter
            def user_file_filter=(filter)
                @user_file_filter = filter || Hash.new(true)
            end

            def initialize(linker)
                @linker = linker
                self.user_file_filter = nil
            end

            HEADER = <<-EOD
            <link rel="stylesheet" href="file://#{File.join(RESSOURCES_DIR, 'exception_view.css')}" type="text/css" />
            <script type="text/javascript" src="file://#{File.join(RESSOURCES_DIR, 'jquery.min.js')}"></script>
            EOD

            SCRIPTS = <<-EOD
            <script type="text/javascript">
            $(document).ready(function () {
                $("tr.backtrace").hide()
                $("a.backtrace_toggle_filtered").click(function (event) {
                        var eventId = $(this).attr("id");
                        $("#backtrace_full_" + eventId).hide();
                        $("#backtrace_filtered_" + eventId).toggle();
                        event.preventDefault();
                        });
                $("a.backtrace_toggle_full").click(function (event) {
                        var eventId = $(this).attr("id");
                        $("#backtrace_full_" + eventId).toggle();
                        $("#backtrace_filtered_" + eventId).hide();
                        event.preventDefault();
                        });
            });
            </script>
            EOD

            # Contents necessary in the <head> ... </head> section
            def head
                HEADER
            end

            # Scripts block to be added to the HTML document
            def scripts
                SCRIPTS
            end

            class BacktraceParser
                def initialize(backtrace)
                    @backtrace = backtrace || []
                end

                def parse
                    call_stack(0)
                end

                def pp_callstack(level)
                    @backtrace[level..-1]
                end

                def pp_call_stack(level)
                    @backtrace[level..-1]
                end
            end

            EXCEPTION_TEMPLATE_WITHOUT_BACKTRACE = <<-EOF
            <tr class="message">
                <td id="<%= idx %>"><%= HTML.escape_html(reason) if reason %><pre><%= message.join("\n") %></pre></td>
            </tr>
            EOF

            EXCEPTION_TEMPLATE_WITH_BACKTRACE = <<-EOF
            <tr class="message">
                <td id="<%= idx %>"><%= HTML.escape_html(reason) if reason %><pre><%= message.join("\n") %></pre>
                <span class="backtrace_links">
                    (show: <a class="backtrace_toggle_filtered" id="<%= idx %>">filtered backtrace</a>,
                           <a class=\"backtrace_toggle_full\" id="<%= idx %>">full backtrace</a>)
                </span>
                </td>
            </tr>
            <tr class="backtrace_summary">
                <td>from <%= origin_file %>:<%= origin_line %>:in <%= HTML.escape_html(origin_method.to_s) %></td>
            </tr>
            <tr class="backtrace" id="backtrace_filtered_<%= idx %>">
                <td><%= render_backtrace(filtered_backtrace) %></td>
            </tr>
            <tr class="backtrace" id="backtrace_full_<%= idx %>">
                <td><%= render_backtrace(full_backtrace) %></td>
            </tr>
            EOF

            # Filters the backtrace to remove framework parts that are not
            # relevant
            #
            # @param [Array<(String,Integer,Symbol)>] the parsed backtrace
            def filter_backtrace(parsed_backtrace, raw_backtrace)
                head = parsed_backtrace.take_while { |file, _| !user_file?(file) }
                tail = parsed_backtrace[head.size..-1].find_all { |file, _| user_file?(file) }
                head + tail
            end

            # Return true if the given file is a user file or a framework file
            #
            # An object used to determine this can be set with
            # {#user_file_filter=}
            def user_file?(file)
                user_file_filter[file]
            end

            def render(e, reason, idx)
                message = PP.pp(e, "").split("\n").
                    map { |line| HTML.escape_html(line) }

                if e.backtrace && !e.backtrace.empty?
                    full_backtrace     = BacktraceParser.new(e.backtrace).parse
                    filtered_backtrace = filter_backtrace(full_backtrace, e.backtrace)
                    if filtered_backtrace.first.respond_to?(:to_str)
                        filtered_backtrace = BacktraceParser.new(filtered_backtrace).parse
                    end

                    origin_file, origin_line, origin_method =
                        filtered_backtrace.find { |file, _| user_file?(file) } ||
                        filtered_backtrace.first ||
                        full_backtrace.first

                    origin_file = linker.link_to(Pathname.new(origin_file), origin_file, lineno: origin_line)
                    ERB.new(EXCEPTION_TEMPLATE_WITH_BACKTRACE).result(binding)
                else
                    ERB.new(EXCEPTION_TEMPLATE_WITHOUT_BACKTRACE).result(binding)
                end
            end

            def render_backtrace(backtrace)
                result = []
                backtrace.each do |file, line, method|
                    file_link = linker.link_to(Pathname.new(file), file, lineno: line)
                    if user_file?(file)
                        result << "  <span class=\"user_file\">#{file_link}:#{line}:in #{HTML.escape_html(method.to_s)}</span><br/>"
                    else
                        result << "  #{file_link}:#{line}:in #{HTML.escape_html(method.to_s)}<br/>"
                    end
                end
                result.join("\n")
            end
        end
    end
end

