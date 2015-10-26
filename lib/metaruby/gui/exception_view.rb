require 'metaruby/gui/html'
require 'metaruby/gui/exception_rendering'

module MetaRuby
    module GUI
        # Widget that allows to display a list of exceptions
        #
        # @deprecated use {HTML::Page} and {HTML::Page#push_exception} directly
        # instead
        class ExceptionView < Qt::WebView
            attr_reader :displayed_exceptions

            # @return [HTML::Page] the page object that allows to infer
            attr_reader :metaruby_page

            # @return [#head,#scripts,#render] an object that allows to render
            #   exceptions in HTML
            attr_reader :exception_rendering

            def initialize(parent = nil)
                super

                @displayed_exceptions = []
                self.focus_policy = Qt::NoFocus

                @metaruby_page = HTML::Page.new(self.page)
                connect(@metaruby_page, SIGNAL('fileOpenClicked(const QUrl&)'),
                        self, SLOT('fileOpenClicked(const QUrl&)'))
                @exception_rendering = ExceptionRendering.new(metaruby_page)

                if ENV['METARUBY_GUI_DEBUG_HTML']
                    page.settings.setAttribute(Qt::WebSettings::DeveloperExtrasEnabled, true)
                    @inspector = Qt::WebInspector.new
                    @inspector.page = page
                    @inspector.show
                end
            end

            def user_file_filter=(filter)
                exception_rendering.user_file_filter = filter
            end

            def push(exception, reason = nil)
                @displayed_exceptions << [exception, reason]
                update_html
            end

            def clear
                @displayed_exceptions.clear
                update_html
            end

            def each_exception(&block)
                @displayed_exceptions.each(&block)
            end

            TEMPLATE = <<-EOD
            <head>
            <%= exception_rendering.head %>
            </head>
            <%= exception_rendering.scripts %>
            <body>
            <table class="exception_list">
            <%= each_exception.each_with_index.map do |(e, reason), idx|
                    exception_rendering.render(e, reason, idx)
                end.join("\\n") %>
            </table>
            </body>
            EOD

            def update_html
                self.html = ERB.new(TEMPLATE).result(binding)
            end

            def exceptions=(list)
                @displayed_exceptions = list.dup
                update_html
            end

            def contents_height
                self.page.main_frame.contents_size.height
            end

            signals 'fileOpenClicked(const QUrl&)'
        end
    end
end

