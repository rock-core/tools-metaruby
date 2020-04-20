# frozen_string_literal: true

module MetaRuby
    module GUI
        # Functionality to render exceptions in an HTML view
        #
        # On top of properly formatting the exception, it introduces backtrace
        # filtering and javascript-based buttons to enable backtraces on or off.
        #
        # It is usually not used directly, but through {HTML::Page}
        #
        # @see HTML::Page#enable_exception_rendering
        # @see HTML::Page#push_exception
        class ExceptionRendering
            # The directory relative to which ressources (such as css or javascript
            # files) are resolved by default
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

            # Create an exception rendering object using the given linker object
            #
            # @param [#link_to] linker
            def initialize(linker)
                @linker = linker
                self.user_file_filter = nil
            end

            # Necessary header content
            HEADER = <<~HTML
                <link rel="stylesheet"
                      href="file://#{File.join(RESSOURCES_DIR, 'exception_view.css')}"
                      type="text/css" />
                <script type="text/javascript"
                        src="file://#{File.join(RESSOURCES_DIR, 'exception_view.js')}">
                </script>
            HTML

            # The scripts that are used by the other exception templates
            SCRIPTS = ""

            # Contents necessary in the <head> ... </head> section
            #
            # It is used when enabling the renderer on a [Page] by calling
            # {HTML::Page#add_to_setup}
            def head
                HEADER
            end

            # Scripts block to be added to the HTML document
            #
            # It is used when enabling the renderer on a [Page] by calling
            # {HTML::Page#add_to_setup}
            def scripts
                SCRIPTS
            end

            # Parse a backtrace into its file, line and method consistuents
            #
            # @return [Array<(String,Integer,String)>]
            def self.parse_backtrace(backtrace)
                BacktraceParser.new(backtrace).parse
            end

            # Shim class that parses a backtrace into its constituents
            #
            # This is an internal class, that should not be used directly. Use
            # {ExceptionRendering.parse_backtrace} instead.
            #
            # It provides the methods required for facet's #call_stack method to
            # work, thus allowing to use it to parse an arbitrary backtrace
            class BacktraceParser
                # Create a parser for the given backtrace
                def initialize(backtrace)
                    @backtrace = backtrace || []
                end

                # Parse the backtrace into file, line and method
                #
                # @return [Array<(String,Integer,String)>]
                def parse
                    call_stack(0)
                end

                # Returns the backtrace
                #
                # This is required by facet's #call_stack
                def pp_callstack(level)
                    @backtrace[level..-1]
                end

                # Returns the backtrace
                #
                # This is required by facet's #call_stack
                def pp_call_stack(level)
                    @backtrace[level..-1]
                end
            end

            # Template used to render an exception that does not have backtrace
            EXCEPTION_TEMPLATE_WITHOUT_BACKTRACE = <<~HTML
                <div class="message" id="<%= id %>">
                    <pre><%= message.join("\n") %></pre>
                </div>
            HTML

            # Template used to render an exception that does have a backtrace
            EXCEPTION_TEMPLATE_WITH_BACKTRACE = <<~HTML
                <div class="message" id="<%= id %>">
                    <pre><%= message.join("\n") %></pre>
                    <span class="backtrace_links">
                        (show: <a class="backtrace_toggle_filtered"
                            id="<%= id %>"
                            onclick="toggleFilteredBacktraceVisibility(this)">
                            filtered backtrace
                        </a>, <a class="backtrace_toggle_full"
                            id="<%= id %>"
                            onclick="toggleFullBacktraceVisibility(this)">
                            full backtrace</a>)
                    </span>
                </div>
                <div class="backtrace_summary">
                    from <%= origin_file %>:<%= origin_line %>:in
                    <%= HTML.escape_html(origin_method.to_s) %>
                </div>
                <div class="backtrace" id="backtrace_filtered_<%= id %>"
                    <%= render_backtrace(filtered_backtrace) %>
                </div>
                <div class="backtrace" id="backtrace_full_<%= id %>"
                     onclick="toggleFullBacktraceVisibility(this)">
                    <%= render_backtrace(full_backtrace) %>
                </div>
            HTML

            # Filters the backtrace to remove framework parts that are not
            # relevant
            #
            # @param [Array<(String,Integer,Symbol)>] parsed_backtrace the parsed backtrace
            # @param [Array<(String,Integer,Symbol)>] raw_backtrace the raw backtrace
            def filter_backtrace(parsed_backtrace, raw_backtrace)
                head = parsed_backtrace.take_while { |file, _| !user_file?(file) }
                tail = parsed_backtrace[head.size..-1].find_all { |file, _| user_file?(file) }
                head + tail
            end

            # Return true if the given file is a user file or a framework file
            #
            # An object used to determine this can be set with
            # {#user_file_filter=}
            #
            # This is used by {#render_backtrace} to choose the style of a
            # backtrace line
            def user_file?(file)
                user_file_filter[file]
            end

            @@exception_id = 0

            # Automatically generate an exception ID
            def allocate_exception_id
                @@exception_id += 1
            end

            # Render an exception into HTML
            #
            # @param [Exception] e the exception to be rendered
            # @param [String] reason additional string that describes the
            #   exception reason
            # @param [String] id the ID that should be used to identify the
            #   exception. Since a given exception can "contain" more than one
            #   (see {#each_exception_from}), a -#counter pattern is added to
            #   the ID.
            # @return [String]
            def render(e, reason = nil, id = allocate_exception_id)
                counter = 0
                html = []
                seen = Set.new
                each_exception_from(e) do |exception|
                    if !seen.include?(exception)
                        seen << exception
                        html << render_single_exception(exception, "#{id}-#{counter += 1}")
                    end
                end
                html.join("\n")
            end

            # Method used by {#render} to discover all exception objects that
            # are linked to another exception, in cases where exceptions cause
            # one another
            #
            # The default implementation only yields 'e', reimplement in
            # subclasses
            #
            # @yieldparam [Exception] exception an exception
            def each_exception_from(e)
                return enum_for(__method__) if !block_given?
                yield(e)
            end

            # @api private
            #
            # Parses the exception backtrace, and generate a parsed raw and
            # parsed filtered version of it
            #
            # @return [(Array<(String,Integer,String)>,Array<(String,Integer,String))>
            #   the full and filtered backtraces, as list of tuples
            #   (file,line,method)
            def parse_and_filter_backtrace(backtrace)
                full_backtrace = ExceptionRendering.parse_backtrace(backtrace)
                filtered_backtrace = filter_backtrace(full_backtrace, backtrace)
                if filtered_backtrace.first.respond_to?(:to_str)
                    filtered_backtrace = ExceptionRendering.parse_backtrace(filtered_backtrace)
                end
                return full_backtrace, filtered_backtrace
            end

            # @api private
            #
            # Render a single exception object into a HTML block
            #
            # @param [Exception] e the exception
            # @param [String] id the block ID
            # @return [String]
            def render_single_exception(e, id)
                message =
                    PP.pp(e, "".dup)
                      .split("\n")
                      .map { |line| HTML.escape_html(line) }

                full_backtrace, filtered_backtrace =
                    parse_and_filter_backtrace(e.backtrace || [])

                unless full_backtrace.empty?
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

            # @api private
            #
            # Render a backtrace
            #
            # It uses {#linker} to generate links, and {#user_file?} to change
            # the style of the backtrace line.
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

