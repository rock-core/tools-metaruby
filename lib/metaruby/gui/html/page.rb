module MetaRuby::GUI
    module HTML
        RESSOURCES_DIR = File.expand_path(File.dirname(__FILE__))

        # A class that can be used as the webpage container for the Page class
        class HTMLPage
            attr_accessor :html

            def main_frame; self end
        end

        # A helper class that gives us easy-to-use page elements on a
        # Qt::WebView
        class Page < Qt::Object
            attr_reader :fragments
            attr_reader :view
            attr_accessor :object_uris

            class Fragment
                attr_accessor :title
                attr_accessor :html
                attr_accessor :id
                attr_reader :buttons

                def initialize(title, html, view_options = Hash.new)
                    view_options = Kernel.validate_options view_options,
                        :id => nil, :buttons => []
                    @title = title
                    @html = html
                    @id = view_options[:id]
                    @buttons = view_options[:buttons]
                end
            end

            def link_to(object, text = nil)
                text = HTML.escape_html(text || object.name)
                if uri = object_uris[object]
                    "<a href=\"link://metaruby#{uri}\">#{text}</a>"
                else text
                end
            end

            PAGE_TEMPLATE = <<-EOD
            <html>
            <link rel="stylesheet" href="file://#{File.join(RESSOURCES_DIR, 'page.css')}" type="text/css" />
            <script type="text/javascript" src="file://#{File.join(RESSOURCES_DIR, 'jquery.min.js')}"></script>
            </html>
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
            <body>
            <%= html_body %>
            </body>
            EOD

            PAGE_BODY_TEMPLATE = <<-EOD
            <% if title %>
            <h1><%= title %></h1>
            <% end %>
            <% fragments.each do |fragment| %>
            <% if fragment.title %>
                <h2><%= fragment.title %></h2>
            <% end %>
            <%= HTML.render_button_bar(fragment.buttons) %>
            <% if fragment.id %>
            <div id="<%= fragment.id %>">
            <% end %>
            <%= fragment.html %>
            <% if fragment.id %>
            </div>
            <% end %>
            <% end %>
            EOD

            attr_reader :page

            def initialize(page)
                begin
                    @page = page.page
                rescue NoMethodError
                    @page = page
                end
                page = self.page

                super()
                @fragments = []

                if page.kind_of?(Qt::WebPage)
                    page.link_delegation_policy = Qt::WebPage::DelegateAllLinks
                    Qt::Object.connect(page, SIGNAL('linkClicked(const QUrl&)'), self, SLOT('pageLinkClicked(const QUrl&)'))
                end
                @object_uris = Hash.new
            end

            attr_accessor :title

            # Removes all existing displays
            def clear
                page.main_frame.html = ""
                fragments.clear
            end

            def scale_attribute(node, name, scale)
                node.attributes[name] = node.attributes[name].gsub /[\d\.]+/ do |n|
                    (Float(n) * scale).to_s
                end
            end

            def update_html
                page.main_frame.html = html
            end

            def html
                ERB.new(PAGE_TEMPLATE).result(binding)
            end

            def html_body
                ERB.new(PAGE_BODY_TEMPLATE).result(binding)
            end

            def find_button_by_url(url)
                id = url.path
                fragments.each do |fragment|
                    if result = fragment.buttons.find { |b| b.id == id }
                        return result
                    end
                end
                nil
            end

            def find_first_element(selector)
                page.main_frame.find_first_element(selector)
            end

            def pageLinkClicked(url)
                return if url.host != 'metaruby'

                if btn = find_button_by_url(url)
                    new_state = if url.fragment == 'on' then true
                                else false
                                end

                    btn.state = new_state
                    new_text = btn.text
                    element = find_first_element("a##{btn.html_id}")
                    element.replace(btn.render)

                    emit buttonClicked(btn.id, new_state)
                else
                    emit linkClicked(url)
                end
            end
            slots 'pageLinkClicked(const QUrl&)'
            signals 'linkClicked(const QUrl&)', 'buttonClicked(const QString&,bool)'

            # Adds a fragment to this page, with the given title and HTML
            # content
            #
            # The added fragment is enclosed in a div block to allow for dynamic
            # replacement
            # 
            # @option view_options [String] id the ID of the fragment. If given,
            #   and if an existing fragment with the same ID exists, the new
            #   fragment replaces the existing one, and the view is updated
            #   accordingly.
            #
            def push(title, html, view_options = Hash.new)
                if id = view_options[:id]
                    # Check whether we should replace the existing content or
                    # push it new
                    fragment = fragments.find do |fragment|
                        fragment.id == id
                    end
                    if fragment
                        fragment.html = html
                        element = find_first_element("div##{fragment.id}")
                        element.replace("<div id=\"#{id}\">#{html}</div>")
                        return
                    end
                end

                fragments << Fragment.new(title, html, view_options)
                update_html
            end

            # Create an item for the rendering in tables
            def render_item(name, value = nil)
                if value
                    "<li><b>#{name}</b>: #{value}</li>"
                else
                    "<li>#{name}</li>"
                end
            end

            signals 'updated()'

            # Renders an object to HTML using a given rendering class
            def self.to_html(object, renderer)
                webpage = HTMLPage.new
                page = new(webpage)
                renderer.new(page).render(object)
                page.html
            end

            def self.to_html_body(object, renderer)
                webpage = HTMLPage.new
                page = new(webpage)
                renderer.new(page).render(object)
                page.html_body
            end
        end
    end
end

