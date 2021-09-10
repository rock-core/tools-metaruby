module MetaRuby::GUI
    module HTML
        # The directory relative to which ressources (such as css or javascript
        # files) are resolved by default
        RESSOURCES_DIR = File.expand_path(File.dirname(__FILE__))

        # A class that can be used as the webpage container for the Page class
        class HTMLPage
            # The HTML content
            attr_accessor :html

            # Method expected by {Page}
            def main_frame; self end
        end

        # A helper class that gives us easy-to-use page elements on a
        # Qt::WebView
        #
        # Such a page is managed as a list of sections (called {Fragment}). A
        # new fragment is added or updated with {#push}
        class Page < Qt::Object
            # The content of the <title> tag
            # @return [String,nil]
            attr_accessor :page_name

            # The content of a toplevel <h1> tag
            # @return [String,nil]
            attr_accessor :title

            # The underlying page rendering object
            #
            # @return [Qt::WebPage,HTMLPage]
            attr_reader :page

            # List of fragments
            #
            # @return [Array<Fragment>]
            attr_reader :fragments

            # Static mapping of objects to URIs
            #
            # @see #uri_fo
            attr_accessor :object_uris

            # Content to be rendered in the page head
            #
            # @return [Array<String>]
            attr_reader :head

            # Scripts to be loaded in the page
            #
            # @return [Array<String>]
            attr_reader :scripts

            # Object used to render exceptions in {#push_exception}
            #
            # It is set by {#enable_exception_rendering}
            #
            # @return [#render]
            attr_reader :exception_rendering

            # Creates a new Page object
            #
            # @param [Qt::WebPage,HTMLPage] page
            def initialize(page)
                super()
                @page = page
                @head = []
                @scripts = []
                @fragments = []
                @templates = {}
                @auto_id = 0

                if defined?(Qt::WebPage) && page.kind_of?(Qt::WebPage)
                    page.link_delegation_policy = Qt::WebPage::DelegateAllLinks
                    Qt::Object.connect(
                        page, SIGNAL("linkClicked(const QUrl&)"),
                        self, SLOT("pageLinkClicked(const QUrl&)")
                    )
                end
                @object_uris = {}
            end

            # A page fragment (or section)
            class Fragment
                # The fragmen title (rendered with <h2>)
                attr_accessor :title
                # The fragment's HTML content
                attr_accessor :html
                # The fragment ID (as, in, HTML id)
                attr_accessor :id
                # A list of buttons to be rendered before the fragment title and
                # its content
                #
                # @return [Array<Button>]
                attr_reader :buttons

                # Create a new fragment
                def initialize(title, html, id: nil, buttons: [])
                    @title = title
                    @html = html
                    @id = id
                    @buttons = buttons
                end
            end

            # Add content to the page setup (head and scripts)
            #
            # @param [#head,#scripts] obj the object defining the content to be
            #   added
            # @see add_to_head add_scripts
            def add_to_setup(obj)
                add_to_head(obj.head)
                add_script(obj.scripts)
            end

            # Add content to {#head}
            #
            # @param [String] html
            def add_to_head(html)
                head << html
            end

            # Add content to {#scripts}
            #
            # @param [String] html
            def add_script(html)
                scripts << html
            end

            # Resolves a relative path to a path in the underlying application's
            # resource folder
            #
            # @return [String]
            def path_in_resource(path)
                if Pathname.new(path).absolute?
                    path
                else
                    File.join('${RESOURCE_DIR}', path)
                end
            end

            # Load a javascript file in the head
            def load_javascript(file)
                add_to_head(
                    "<script type=\"text/javascript\" src=\"#{path_in_resource(file)}\"></script>")
            end

            # Helper that generates a HTML link to a given object
            #
            # The object URI is resolved using {#uri_for}. If there is no known
            # link to the object, it is returned as text
            #
            # @param [Object] object the object to create a link to
            # @param [String] text the link text. Defaults to object#name
            # @return [String]
            def link_to(object, text = nil, **args)
                text = HTML.escape_html(text || object.name || "<anonymous>")
                if uri = uri_for(object)
                    if uri !~ /^\w+:\/\//
                        if uri[0, 1] != '/'
                            uri = "/#{uri}"
                        end
                        uri = Qt::Url.new("link://metaruby#{uri}")
                    else
                        uri = Qt::Url.new(uri)
                    end
                    args.each { |k, v| uri.add_query_item(k.to_s, v.to_s) }
                    "<a href=\"#{uri.to_string}\">#{text}</a>"
                else text
                end
            end

            # Converts the given text from markdown to HTML and generates the
            # necessary <div> context.
            #
            # @return [String] the HTML snippet that should be used to render
            #   the given text as main documentation
            def self.main_doc(text)
                "<div class=\"doc-main\">#{Kramdown::Document.new(text).to_html}</div>"
            end

            def main_doc(text)
                self.class.main_doc(text)
            end

            # The ERB template for a page
            #
            # @see html
            PAGE_TEMPLATE = File.join(RESSOURCES_DIR, "page.rhtml")
            # The ERB template for a page body
            #
            # @see html_body
            PAGE_BODY_TEMPLATE = File.join(RESSOURCES_DIR, "page_body.rhtml")
            # The ERB template for a page fragment
            #
            # @see push
            FRAGMENT_TEMPLATE  = File.join(RESSOURCES_DIR, "fragment.rhtml")
            # The ERB template for a list
            #
            # @see render_list
            LIST_TEMPLATE = File.join(RESSOURCES_DIR, "list.rhtml")
            # Assets (CSS, javascript) that are included in every page
            ASSETS = %w{page.css jquery.min.js jquery.selectfilter.js}

            # Copy the assets to a target directory
            #
            # This can be used to create self-contained HTML pages using the
            # Page class, by providing a different ressource dir to e.g. {#html}
            # or {#html_body} and copying the assets to it.
            def self.copy_assets_to(target_dir, assets = ASSETS)
                FileUtils.mkdir_p target_dir
                assets.each do |file|
                    FileUtils.cp File.join(RESSOURCES_DIR, file), target_dir
                end
            end

            # Lazy loads a template
            #
            # @return [ERB]
            def load_template(*path)
                path = File.join(*path)
                @templates[path] ||= ERB.new(File.read(path))
                @templates[path].filename = path
                @templates[path]
            end

            # Generate a URI for an object
            #
            # The method must either return a string that is a URI representing
            # the object, or nil if there is none. The choice of the URI is
            # application-specific, used by the application to recognize links
            #
            # The default application returns a file:/// URI for a Pathname
            # object, and then uses {#object_uris}
            #
            # @see link_to
            def uri_for(object)
                if object.kind_of?(Pathname)
                    "file://#{object.expand_path}"
                else
                    object_uris[object]
                end
            end

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

            # Generate the HTML and update the underlying {#page}
            def update_html
                page.main_frame.html = html
            end

            # Generate the HTML
            #
            # @param [String] ressource_dir the path to the ressource directory
            #   that {#path_in_resource} should use
            def html(ressource_dir: RESSOURCES_DIR)
                load_template(PAGE_TEMPLATE).result(binding)
            end

            # Generate the body of the HTML document
            #
            # @param [String] ressource_dir the path to the ressource directory
            #   that {#path_in_resource} should use
            def html_body(ressource_dir: RESSOURCES_DIR)
                load_template(PAGE_BODY_TEMPLATE).result(binding)
            end

            # Generate the HTML of a fragment
            #
            # @param [String] ressource_dir the path to the ressource directory
            #   that {#path_in_resource} should use
            def html_fragment(fragment, ressource_dir: RESSOURCES_DIR)
                load_template(FRAGMENT_TEMPLATE).result(binding)
            end

            # Find a button from its URI
            #
            # @return [Button,nil]
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

            # @api private
            #
            # Slot that catches the page's link-clicked signal and dispatches
            # into the buttonClicked signal (for buttons), fileClicked for files
            # and linkClicked for links
            def pageLinkClicked(url)
                if url.scheme == 'btn' && url.host == 'metaruby'
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
                        MetaRuby.warn "invalid button URI #{url.to_string}: could not find corresponding handler (known buttons are #{fragments.flat_map { |f| f.buttons.map { |btn| btn.id.to_string } }.sort.join(", ")})"
                    end
                elsif url.scheme == 'link' && url.host == 'metaruby'
                    emit linkClicked(url)
                elsif url.scheme == "file"
                    emit fileOpenClicked(url)
                else
                    MetaRuby.warn "MetaRuby::GUI::HTML::Page: ignored link #{url.toString}"
                end
            end
            slots "pageLinkClicked(const QUrl&)"
            signals "linkClicked(const QUrl&)",
                    "buttonClicked(const QString&,bool)",
                    "fileOpenClicked(const QUrl&)"

            # Save the current state of the page, so that it can be restored by
            # calling {#restore}
            def save
                @saved_state = fragments.map(&:dup)
            end

            # Restore the page at the state it was at the last call to {#save}
            def restore
                return if !@saved_state

                fragments_by_id = Hash.new
                @saved_state.each do |fragment|
                    fragments_by_id[fragment.id] = fragment
                end

                # Delete all fragments that are not in the saved state
                fragments.delete_if do |fragment|
                    element = find_first_element("div##{fragment.id}")
                    if old_fragment = fragments_by_id[fragment.id]
                        if old_fragment.html != fragment.html
                            element.replace(old_fragment.html)
                        end
                    else
                        element.replace("")
                        true
                    end
                end
            end

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
            def push(title, html, id: auto_id, **view_options)
                if id && (fragment = fragments.find { |f| f.id == id })
                    # Check whether we should replace the existing content or
                    # push it new

                    fragment.html = html
                    element = find_first_element("div##{fragment.id}")
                    element.replace(html_fragment(fragment))
                    return
                end

                fragments << Fragment.new(title, html, id: id, **view_options)
                update_html
            end

            # Automatic generation of a fragment ID
            def auto_id
                "metaruby-html-page-fragment-#{@auto_id += 1}"
            end

            # Enable rendering of exceptions using the given renderer
            #
            # @param [ExceptionRendering] renderer
            def enable_exception_rendering(renderer = ExceptionRendering.new(self))
                add_to_setup(renderer)
                @exception_rendering = renderer
            end

            # Push a fragment that represents the given exception
            #
            # {#enable_exception_rendering} must have been called first
            #
            # @param [String] title the fragment title
            # @param [Exception] e the exception to render
            # @param [String] id the fragment ID
            # @param [Hash] options additional options passed to {#push}
            def push_exception(title, e, id: auto_id, **options)
                html = exception_rendering.render(e, nil, id)
                push(title, html, id: id, **options)
            end

            # Create an item for the rendering in tables
            def render_item(name, value = nil)
                if value
                    "<li><b>#{name}</b>: #{value}</li>"
                else
                    "<li>#{name}</li>"
                end
            end

            # Render a list of objects into HTML and push it to this page
            #
            # @param [String,nil] title the section's title. If nil, no new
            #   section is created
            # @param [Array<Object>,Array<(Object,Hash)>] items the list
            #   items, one item per line. If a hash is provided, it is used as
            #   HTML attributes for the lines
            # @param [Boolean] filter only render the items with the given 'id'
            # @param [String] id the id to filter if filter: is true
            # @param [Hash] push_options options that are passed to
            #   {#push}. The id: option is added to it.
            def render_list(title, items, filter: false, id: nil, **push_options)
                if filter && !id
                    raise ArgumentError, ":filter is true, but no :id has been given"
                end

                html = load_template(LIST_TEMPLATE).result(binding)
                push(title, html, **push_options.merge(id: id))
            end

            signals 'updated()'

            # Renders an object into a HTML page
            #
            # @param [Object] object
            # @param [#render] renderer the object that renders into the page.
            #   The object must accept a {Page} at initialization and its
            #   #render method gets called passing the object and rendering
            #   options
            # @return [Page]
            def self.to_html_page(object, renderer, **options)
                webpage = HTMLPage.new
                page = new(webpage)
                renderer.new(page).render(object, **options)
                page
            end

            # Renders an object into a HTML page
            #
            # @param (see to_html_page)
            # @return [String]
            def self.to_html(object, renderer, ressource_dir: RESSOURCES_DIR, **options)
                to_html_page(object, renderer, **options).
                    html(ressource_dir: ressource_dir)
            end

            # Renders an object into a HTML body
            #
            # @param (see to_html_page)
            # @return [String]
            def self.to_html_body(object, renderer, ressource_dir: RESSOURCES_DIR, **options)
                to_html_page(object, renderer, **options).
                    html_body(ressource_dir: ressource_dir)
            end
        end
    end
end

